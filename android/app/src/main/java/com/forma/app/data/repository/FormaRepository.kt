package com.forma.app.data.repository

import android.content.Context
import com.forma.app.data.local.DatabaseHelper
import com.forma.app.data.model.*
import com.forma.app.data.remote.BackendApiClient
import com.google.gson.Gson
import com.google.gson.JsonObject
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.text.SimpleDateFormat
import java.util.*

data class DailySummary(
    val totalCalories: Int = 0,
    val totalBurnedCalories: Int = 0,
    val totalWaterMl: Int = 0,
    val totalProtein: Int = 0,
    val totalCarbs: Int = 0,
    val totalFat: Int = 0
)

data class AuthUser(
    val id: String,
    val email: String,
    val name: String
)

class FormaRepository(
    private val context: Context,
    private val db: DatabaseHelper
) {
    val backendClient = BackendApiClient(context)
    val apiClient: BackendApiClient get() = backendClient
    private val gson = Gson()
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    // Profile & Auth
    private val _userProfile = MutableStateFlow(db.getProfile())
    val userProfile: StateFlow<UserProfile> = _userProfile.asStateFlow()
    val profile: StateFlow<UserProfile> = _userProfile

    private val _authUser = MutableStateFlow<AuthUser?>(
        if (backendClient.isAuthenticated) {
            AuthUser(
                id = backendClient.userId ?: "user",
                email = backendClient.userEmail ?: "",
                name = backendClient.userName ?: _userProfile.value.name
            )
        } else null
    )
    val authUser: StateFlow<AuthUser?> = _authUser.asStateFlow()

    // Data lists
    private val _foodEntries = MutableStateFlow(db.getAllFoods())
    val foodEntries: StateFlow<List<FoodEntry>> = _foodEntries.asStateFlow()
    val foods: StateFlow<List<FoodEntry>> = _foodEntries

    private val _workoutEntries = MutableStateFlow(db.getAllWorkouts())
    val workoutEntries: StateFlow<List<WorkoutEntry>> = _workoutEntries.asStateFlow()
    val workouts: StateFlow<List<WorkoutEntry>> = _workoutEntries

    private val _waters = MutableStateFlow(db.getAllWaters())
    val waters: StateFlow<List<WaterEntry>> = _waters.asStateFlow()

    private val _weightEntries = MutableStateFlow(db.getAllWeights())
    val weightEntries: StateFlow<List<WeightEntry>> = _weightEntries.asStateFlow()
    val weights: StateFlow<List<WeightEntry>> = _weightEntries

    private val _workoutRoutines = MutableStateFlow(db.getAllRoutines())
    val workoutRoutines: StateFlow<List<WorkoutRoutine>> = _workoutRoutines.asStateFlow()
    val routines: StateFlow<List<WorkoutRoutine>> = _workoutRoutines

    private val _aiAnalyses = MutableStateFlow(db.getLatestAnalysis()?.let { listOf(it) } ?: emptyList())
    val aiAnalyses: StateFlow<List<EvolutionAIAnalysis>> = _aiAnalyses.asStateFlow()
    val latestAnalysis: StateFlow<EvolutionAIAnalysis?> get() = MutableStateFlow(_aiAnalyses.value.firstOrNull()).asStateFlow()

    // Daily Summary
    private val _dailySummary = MutableStateFlow(calculateTodaySummary())
    val dailySummary: StateFlow<DailySummary> = _dailySummary.asStateFlow()

    // Workout Live Activity / Island
    private val _isWorkoutActive = MutableStateFlow(false)
    val isWorkoutActive: StateFlow<Boolean> = _isWorkoutActive.asStateFlow()

    private val _workoutDurationSeconds = MutableStateFlow(0)
    val workoutDurationSeconds: StateFlow<Int> = _workoutDurationSeconds.asStateFlow()

    private val _activeWorkoutName = MutableStateFlow("Treino")
    val activeWorkoutName: StateFlow<String> = _activeWorkoutName.asStateFlow()

    private var workoutTimerJob: Job? = null

    init {
        recalculateSummary()
    }

    fun isLoggedIn(): Boolean {
        return backendClient.isAuthenticated || backendClient.isGuest
    }

    fun getTodayWater(): Int = _dailySummary.value.totalWaterMl
    fun getTodayCaloriesConsumed(): Double = _dailySummary.value.totalCalories.toDouble()

    // --- Profile Updates & Contextual Recalculation ---
    fun buildRecalculationContext(): RecalculationContext {
        val now = System.currentTimeMillis()
        val sevenDaysMs = 7L * 24L * 3600L * 1000L
        val fourteenDaysMs = 14L * 24L * 3600L * 1000L
        val twentyOneDaysMs = 21L * 24L * 3600L * 1000L

        val workouts14d = _workoutEntries.value.filter { it.workoutDate >= now - fourteenDaysMs }
        val sum14d = workouts14d.sumOf { it.caloriesBurned }
        val sum7d = workouts14d.filter { it.workoutDate >= now - sevenDaysMs }.sumOf { it.caloriesBurned }
        val avgDailyWorkoutBurn = maxOf(sum14d / 14.0, sum7d / 7.0)

        val routines = _workoutRoutines.value
        val routineEstimatedDailyBurn = if (routines.isNotEmpty()) {
            val avgPerSession = routines.sumOf { it.estimatedCalories } / routines.size.toDouble()
            val sessionsPerWeek = routines.size.coerceIn(3, 5).toDouble()
            (avgPerSession * sessionsPerWeek) / 7.0
        } else 0.0

        val recentWeights = _weightEntries.value
            .filter { it.entryDate >= now - twentyOneDaysMs }
            .sortedBy { it.entryDate }
        var weeklyTrend: Double? = null
        if (recentWeights.size >= 2) {
            val first = recentWeights.first()
            val last = recentWeights.last()
            val daysSpan = (last.entryDate - first.entryDate).toDouble() / (24.0 * 3600.0 * 1000.0)
            if (daysSpan >= 4.0) {
                weeklyTrend = ((last.weight - first.weight) / daysSpan) * 7.0
            }
        }

        return RecalculationContext(
            workoutsLast14DaysCount = workouts14d.size,
            avgDailyWorkoutBurn = avgDailyWorkoutBurn,
            routineEstimatedDailyBurn = routineEstimatedDailyBurn,
            recentAvgSteps = 0.0,
            weeklyWeightTrendKg = weeklyTrend
        )
    }

    fun previewRecalculatedProfile(
        newWeight: Double = _userProfile.value.currentWeight,
        newHeight: Double = _userProfile.value.heightMeters,
        newGoal: FitnessGoal = _userProfile.value.goal,
        newTargetWeight: Double = _userProfile.value.targetWeight
    ): UserProfile {
        return _userProfile.value.recalculated(
            newWeight = newWeight,
            newHeight = newHeight,
            newGoal = newGoal,
            newTargetWeight = newTargetWeight,
            context = buildRecalculationContext()
        )
    }

    fun updateProfile(newProfile: UserProfile) {
        db.saveProfile(newProfile)
        _userProfile.value = newProfile
        recalculateSummary()
    }

    // --- Food Operations ---
    fun addFood(food: FoodEntry) {
        db.insertFood(food)
        _foodEntries.value = db.getAllFoods()
        recalculateSummary()

        val iso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.getDefault()).format(Date(food.consumedAt))
        db.insertActivityLog(
            ActivityLogRecord(
                timestamp = iso,
                category = "meal",
                title = "${food.mealType.title}: ${food.name}",
                isSnack = food.mealType == MealType.SNACKS,
                caloriesChange = food.calories,
                proteinGrams = food.protein,
                carbsGrams = food.carbohydrates,
                fatGrams = food.fat,
                details = "${food.portionGrams}g - ${food.calories} kcal"
            )
        )
    }

    fun deleteFoodEntry(id: String) {
        db.deleteFood(id)
        _foodEntries.value = db.getAllFoods()
        recalculateSummary()
    }

    // --- Workout Operations ---
    fun addWorkout(workout: WorkoutEntry) {
        db.insertWorkout(workout)
        _workoutEntries.value = db.getAllWorkouts()
        val updatedProfile = previewRecalculatedProfile()
        db.saveProfile(updatedProfile)
        _userProfile.value = updatedProfile
        recalculateSummary()

        val iso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.getDefault()).format(Date(workout.workoutDate))
        db.insertActivityLog(
            ActivityLogRecord(
                timestamp = iso,
                category = "workout",
                title = workout.title,
                caloriesChange = -workout.caloriesBurned,
                details = "${workout.workoutType} (${workout.durationMinutes} min) - ${workout.caloriesBurned} kcal queimadas"
            )
        )
    }

    fun deleteWorkoutEntry(id: String) {
        db.deleteWorkout(id)
        _workoutEntries.value = db.getAllWorkouts()
        recalculateSummary()
    }

    // --- Water Operations ---
    fun addWater(ml: Int = 250) {
        val entry = WaterEntry(milliliters = ml)
        db.insertWater(entry)
        _waters.value = db.getAllWaters()
        recalculateSummary()

        val iso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.getDefault()).format(Date())
        db.insertActivityLog(
            ActivityLogRecord(
                timestamp = iso,
                category = "water",
                title = "Hidratação",
                waterMilliliters = ml,
                details = "+$ml ml de água consumidos"
            )
        )
    }

    // --- Weight Operations ---
    fun addWeight(weight: Double, notes: String = "") {
        val entry = WeightEntry(weight = weight, notes = notes)
        db.insertWeight(entry)
        _weightEntries.value = db.getAllWeights()

        val updatedProfile = previewRecalculatedProfile(newWeight = weight)
        updateProfile(updatedProfile)

        val iso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.getDefault()).format(Date())
        db.insertActivityLog(
            ActivityLogRecord(
                timestamp = iso,
                category = "weight",
                title = "Pesagem",
                weightKg = weight,
                details = "Peso registrado: $weight kg"
            )
        )
    }

    // --- Live Workout Timer ---
    fun startWorkout(title: String = "Musculação") {
        workoutTimerJob?.cancel()
        _activeWorkoutName.value = title
        _workoutDurationSeconds.value = 0
        _isWorkoutActive.value = true

        workoutTimerJob = scope.launch {
            while (_isWorkoutActive.value) {
                delay(1000)
                _workoutDurationSeconds.value += 1
            }
        }
    }

    fun stopWorkout() {
        if (!_isWorkoutActive.value) return
        val durationSecs = _workoutDurationSeconds.value
        val durationMins = (durationSecs / 60).coerceAtLeast(1)
        val burnedEst = (durationSecs * 0.12).toInt().coerceAtLeast(15)

        val workout = WorkoutEntry(
            title = _activeWorkoutName.value,
            workoutType = "Treino",
            durationMinutes = durationMins,
            caloriesBurned = burnedEst.toDouble(),
            notes = "Treino finalizado na Ilha Dinâmica ($durationMins min)"
        )
        addWorkout(workout)

        _isWorkoutActive.value = false
        workoutTimerJob?.cancel()
        workoutTimerJob = null
    }

    // --- Daily Summary Calculation ---
    private fun recalculateSummary() {
        _dailySummary.value = calculateTodaySummary()
    }

    private fun calculateTodaySummary(): DailySummary {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val todayStart = cal.timeInMillis

        val foodsToday = _foodEntries.value.filter { it.consumedAt >= todayStart }
        val workoutsToday = _workoutEntries.value.filter { it.workoutDate >= todayStart }
        val watersToday = _waters.value.filter { it.entryDate >= todayStart }

        val totalCalories = foodsToday.sumOf { it.calories }.toInt()
        val totalBurned = workoutsToday.sumOf { it.caloriesBurned }.toInt()
        val totalWater = watersToday.sumOf { it.milliliters }
        val totalProtein = foodsToday.sumOf { it.protein }.toInt()
        val totalCarbs = foodsToday.sumOf { it.carbohydrates }.toInt()
        val totalFat = foodsToday.sumOf { it.fat }.toInt()

        return DailySummary(
            totalCalories = totalCalories,
            totalBurnedCalories = totalBurned,
            totalWaterMl = totalWater,
            totalProtein = totalProtein,
            totalCarbs = totalCarbs,
            totalFat = totalFat
        )
    }

    // --- AI Requests via Backend Proxy ---
    suspend fun analyzeMeal(text: String, mealType: String, isSnack: Boolean): Result<FoodEntry> {
        val userPrompt = "Refeição: $text (Tipo: $mealType, Lanche: $isSnack)"
        val userName = _userProfile.value.name
        val result = backendClient.analyzeMeal(userPrompt, userName)

        return if (result.isSuccess) {
            val jsonStr = result.getOrNull() ?: ""
            try {
                val clean = cleanJson(jsonStr)
                val obj = gson.fromJson(clean, JsonObject::class.java)

                val name = obj.get("name")?.asString ?: text.take(30)
                val portion = obj.get("portionGrams")?.asDouble ?: 100.0
                val calories = obj.get("calories")?.asDouble ?: 250.0
                val protein = obj.get("protein")?.asDouble ?: 10.0
                val carbs = obj.get("carbohydrates")?.asDouble ?: 30.0
                val fat = obj.get("fat")?.asDouble ?: 8.0

                val mt = when (mealType.lowercase()) {
                    "café da manhã" -> MealType.BREAKFAST
                    "jantar" -> MealType.DINNER
                    "lanche", "café da tarde" -> MealType.SNACKS
                    else -> MealType.LUNCH
                }

                val food = FoodEntry(
                    name = name,
                    mealType = mt,
                    portionGrams = portion,
                    calories = calories,
                    protein = protein,
                    carbohydrates = carbs,
                    fat = fat
                )
                addFood(food)
                Result.success(food)
            } catch (e: Exception) {
                // Fallback estimativo caso o parse falhe
                val food = FoodEntry(
                    name = text.take(30),
                    mealType = MealType.LUNCH,
                    calories = 300.0,
                    protein = 15.0,
                    carbohydrates = 35.0,
                    fat = 10.0
                )
                addFood(food)
                Result.success(food)
            }
        } else {
            Result.failure(result.exceptionOrNull() ?: Exception("Falha ao analisar refeição"))
        }
    }

    suspend fun analyzeWorkout(text: String): Result<WorkoutEntry> {
        val userName = _userProfile.value.name
        val userWeight = _userProfile.value.currentWeight
        val result = backendClient.analyzeWorkout(text, userWeight, userName)

        return if (result.isSuccess) {
            val jsonStr = result.getOrNull() ?: ""
            try {
                val clean = cleanJson(jsonStr)
                val obj = gson.fromJson(clean, JsonObject::class.java)

                val title = obj.get("title")?.asString ?: "Treino Estimado"
                val type = obj.get("workoutType")?.asString ?: "Musculação"
                val duration = obj.get("durationMinutes")?.asInt ?: 45
                val calories = obj.get("caloriesBurned")?.asDouble ?: 320.0
                val notes = obj.get("notes")?.asString ?: ""

                val workout = WorkoutEntry(
                    title = title,
                    workoutType = type,
                    durationMinutes = duration,
                    caloriesBurned = calories,
                    notes = notes
                )
                addWorkout(workout)
                Result.success(workout)
            } catch (e: Exception) {
                val workout = WorkoutEntry(
                    title = text.take(30),
                    workoutType = "Treino",
                    durationMinutes = 40,
                    caloriesBurned = 280.0
                )
                addWorkout(workout)
                Result.success(workout)
            }
        } else {
            Result.failure(result.exceptionOrNull() ?: Exception("Falha ao analisar treino"))
        }
    }

    suspend fun analyzeEvolution(): Result<EvolutionAIAnalysis> {
        val p = _userProfile.value
        val userName = p.name
        val logs = db.getAllActivityLogs()
        val logJson = gson.toJson(logs.take(50))
        val ctx = buildRecalculationContext()
        val contextualTdee = p.contextualTdee(context = ctx)
        val contextualProfile = p.recalculated(context = ctx)

        val result = backendClient.analyzeEvolution(
            goal = p.goal.title,
            weight = p.currentWeight,
            targetWeight = p.targetWeight,
            heightMeters = p.heightMeters,
            targetCalories = p.targetCalorieIntake,
            targetCalorieBurn = p.targetCalorieBurn,
            targetSteps = p.targetSteps,
            calculatedTmb = p.tmb,
            contextualTdee = contextualTdee,
            suggestedBaseCalories = contextualProfile.targetCalorieIntake,
            avgDailyWorkoutBurn = ctx.avgDailyWorkoutBurn,
            logJson = logJson,
            userName = userName
        )

        return if (result.isSuccess) {
            val jsonStr = result.getOrNull() ?: ""
            try {
                val clean = cleanJson(jsonStr)
                val analysis = gson.fromJson(clean, EvolutionAIAnalysis::class.java)

                db.insertAnalysis(analysis)
                _aiAnalyses.value = listOf(analysis) + _aiAnalyses.value

                // Se houver rotina recomendada pela IA, salva na tabela de treinos com tag gerada por IA
                analysis.recommendedRoutine?.let { rec ->
                    val routine = WorkoutRoutine(
                        title = "[GERADA POR IA] ${rec.title}",
                        workoutType = rec.workoutType,
                        targetMuscles = rec.targetMuscles,
                        hypertrophyFocus = rec.hypertrophyFocus,
                        estimatedDurationMinutes = rec.estimatedDurationMinutes,
                        estimatedCalories = rec.estimatedCalories,
                        recommendedRestSeconds = rec.recommendedRestSeconds,
                        exercises = rec.exercises,
                        notes = "Rotina recomendada no diagnóstico de evolução da IA para $userName"
                    )
                    db.insertRoutine(routine)
                    _workoutRoutines.value = db.getAllRoutines()
                }

                Result.success(analysis)
            } catch (e: Exception) {
                Result.failure(e)
            }
        } else {
            Result.failure(result.exceptionOrNull() ?: Exception("Falha na análise da IA"))
        }
    }

    private val syncPrefs = context.getSharedPreferences("forma_sync_prefs", Context.MODE_PRIVATE)

    private fun refreshAllFlowsFromDb() {
        _userProfile.value = db.getProfile()
        _foodEntries.value = db.getAllFoods()
        _workoutEntries.value = db.getAllWorkouts()
        _waters.value = db.getAllWaters()
        _weightEntries.value = db.getAllWeights()
        _workoutRoutines.value = db.getAllRoutines()
        _aiAnalyses.value = db.getLatestAnalysis()?.let { listOf(it) } ?: emptyList()
        recalculateSummary()
    }

    private fun prepareLocalStoreForUser(newUserId: String, name: String, email: String) {
        val previousUserId = syncPrefs.getString("active_local_user_id", null)
        if (previousUserId != newUserId) {
            db.clearAllUserData(defaultName = name, defaultEmail = email)
            syncPrefs.edit().putString("active_local_user_id", newUserId).apply()
            refreshAllFlowsFromDb()
        } else {
            val updated = _userProfile.value.copy(name = name, email = email)
            updateProfile(updated)
        }
    }

    // --- Authentication ---
    suspend fun login(email: String, pass: String): Result<String> {
        val res = backendClient.login(email, pass)
        if (res.isSuccess) {
            val uid = backendClient.userId ?: "user"
            val uEmail = backendClient.userEmail ?: email
            val uName = backendClient.userName ?: "Usuário"
            prepareLocalStoreForUser(uid, uName, uEmail)
            _authUser.value = AuthUser(id = uid, email = uEmail, name = uName)
            // Pull cloud data automatically
            syncPull()
        }
        return res
    }

    suspend fun register(name: String, email: String, pass: String): Result<String> {
        val res = backendClient.register(name, email, pass)
        if (res.isSuccess) {
            val uid = backendClient.userId ?: "user"
            val uEmail = backendClient.userEmail ?: email
            prepareLocalStoreForUser(uid, name, uEmail)
            _authUser.value = AuthUser(id = uid, email = uEmail, name = name)
            syncPush()
        }
        return res
    }

    suspend fun loginWithSocial(provider: String, email: String, name: String, providerId: String): Result<String> {
        val res = backendClient.loginSocial(provider, providerId, email, name)
        if (res.isSuccess) {
            val uid = backendClient.userId ?: providerId
            prepareLocalStoreForUser(uid, name, email)
            _authUser.value = AuthUser(id = uid, email = email, name = name)
            syncPull()
        }
        return res
    }

    fun logout() {
        backendClient.logout()
        syncPrefs.edit().remove("active_local_user_id").apply()
        db.clearAllUserData()
        _authUser.value = null
        refreshAllFlowsFromDb()
    }

    // --- Sync Operations ---
    suspend fun syncPush(): Result<Unit> {
        val currentUid = backendClient.userId
        val ackKey = if (!currentUid.isNullOrBlank()) "reset_ack_$currentUid" else null
        val localAck = ackKey?.let { syncPrefs.getLong(it, 0L) } ?: 0L

        val res = backendClient.pushSyncData(
            profile = _userProfile.value,
            foods = _foodEntries.value,
            workouts = _workoutEntries.value,
            waters = _waters.value,
            weights = _weightEntries.value,
            routines = _workoutRoutines.value,
            analyses = _aiAnalyses.value,
            activityLogs = db.getAllActivityLogs(),
            clientResetAckEpochMs = localAck.takeIf { it > 0L }
        )

        if (res.isFailure) {
            val errMsg = res.exceptionOrNull()?.message ?: ""
            if (errMsg.contains("accountDeleted")) {
                logout()
            }
            return Result.failure(res.exceptionOrNull() ?: Exception("Sync push failed"))
        }

        val body = res.getOrNull() ?: ""
        if (body.contains("reset_required")) {
            try {
                val root = gson.fromJson(body, JsonObject::class.java)
                val forceMs = root.get("forceResetEpochMs")?.takeIf { !it.isJsonNull }?.asLong ?: System.currentTimeMillis()
                db.clearAllUserData()
                ackKey?.let { syncPrefs.edit().putLong(it, forceMs).apply() }
                refreshAllFlowsFromDb()
                return syncPull()
            } catch (_: Exception) {
            }
        }

        return Result.success(Unit)
    }

    private fun parseIsoMillis(isoStr: String?): Long {
        if (isoStr.isNullOrBlank()) return System.currentTimeMillis()
        return try {
            java.time.Instant.parse(isoStr).toEpochMilli()
        } catch (_: Exception) {
            System.currentTimeMillis()
        }
    }

    suspend fun syncPull(): Result<Unit> {
        val res = backendClient.pullSyncData()
        return if (res.isSuccess) {
            val body = res.getOrNull()
            if (!body.isNullOrBlank()) {
                try {
                    val root = gson.fromJson(body, JsonObject::class.java)
                    val currentUid = backendClient.userId
                    val ackKey = if (!currentUid.isNullOrBlank()) "reset_ack_$currentUid" else null
                    val forceResetMs = root.get("forceResetEpochMs")?.takeIf { !it.isJsonNull }?.asLong ?: 0L
                    if (forceResetMs > 0L && ackKey != null) {
                        val lastAck = syncPrefs.getLong(ackKey, 0L)
                        if (forceResetMs > lastAck) {
                            db.clearAllUserData()
                            syncPrefs.edit().putLong(ackKey, forceResetMs).apply()
                        }
                    }

                    root.getAsJsonObject("profile")?.let { p ->
                        val goalTitle = p.get("goal")?.takeIf { !it.isJsonNull }?.asString ?: ""
                        val goal = FitnessGoal.values().firstOrNull {
                            it.title.equals(goalTitle, ignoreCase = true) || it.name.equals(goalTitle, ignoreCase = true)
                        } ?: _userProfile.value.goal
                        val current = _userProfile.value
                        val restored = current.copy(
                            name = backendClient.userName ?: current.name,
                            email = backendClient.userEmail ?: current.email,
                            goal = goal,
                            targetCalorieIntake = p.get("targetCalorieIntake")?.takeIf { !it.isJsonNull }?.asDouble ?: current.targetCalorieIntake,
                            targetCalorieBurn = p.get("targetCalorieBurn")?.takeIf { !it.isJsonNull }?.asDouble ?: current.targetCalorieBurn,
                            targetSteps = p.get("targetSteps")?.takeIf { !it.isJsonNull }?.asDouble ?: current.targetSteps,
                            targetWeight = p.get("targetWeight")?.takeIf { !it.isJsonNull }?.asDouble ?: current.targetWeight,
                            targetProtein = p.get("targetProtein")?.takeIf { !it.isJsonNull }?.asDouble ?: current.targetProtein,
                            targetCarbohydrates = p.get("targetCarbohydrates")?.takeIf { !it.isJsonNull }?.asDouble ?: current.targetCarbohydrates,
                            targetFat = p.get("targetFat")?.takeIf { !it.isJsonNull }?.asDouble ?: current.targetFat,
                            targetWaterMilliliters = p.get("targetWaterMilliliters")?.takeIf { !it.isJsonNull }?.asInt ?: current.targetWaterMilliliters,
                            heightMeters = p.get("heightMeters")?.takeIf { !it.isJsonNull }?.asDouble ?: current.heightMeters,
                            currentWeight = p.get("currentWeight")?.takeIf { !it.isJsonNull }?.asDouble ?: current.currentWeight
                        )
                        db.saveProfile(restored)
                    }

                    root.getAsJsonArray("foods")?.forEach { elem ->
                        val obj = elem.asJsonObject
                        val id = obj.get("id")?.takeIf { !it.isJsonNull }?.asString ?: return@forEach
                        val mtRaw = obj.get("mealType")?.takeIf { !it.isJsonNull }?.asString ?: ""
                        val mt = MealType.values().firstOrNull { it.title.equals(mtRaw, ignoreCase = true) } ?: MealType.LUNCH
                        db.insertFood(
                            FoodEntry(
                                id = id,
                                name = obj.get("name")?.takeIf { !it.isJsonNull }?.asString ?: "Alimento",
                                brand = obj.get("brand")?.takeIf { !it.isJsonNull }?.asString ?: "",
                                mealType = mt,
                                portionGrams = obj.get("portionGrams")?.takeIf { !it.isJsonNull }?.asDouble ?: 100.0,
                                calories = obj.get("calories")?.takeIf { !it.isJsonNull }?.asDouble ?: 0.0,
                                protein = obj.get("protein")?.takeIf { !it.isJsonNull }?.asDouble ?: 0.0,
                                carbohydrates = obj.get("carbohydrates")?.takeIf { !it.isJsonNull }?.asDouble ?: 0.0,
                                fat = obj.get("fat")?.takeIf { !it.isJsonNull }?.asDouble ?: 0.0,
                                consumedAt = parseIsoMillis(obj.get("consumedAt")?.takeIf { !it.isJsonNull }?.asString)
                            )
                        )
                    }

                    root.getAsJsonArray("workouts")?.forEach { elem ->
                        val obj = elem.asJsonObject
                        val id = obj.get("id")?.takeIf { !it.isJsonNull }?.asString ?: return@forEach
                        db.insertWorkout(
                            WorkoutEntry(
                                id = id,
                                title = obj.get("title")?.takeIf { !it.isJsonNull }?.asString ?: "Treino",
                                workoutType = obj.get("workoutType")?.takeIf { !it.isJsonNull }?.asString ?: "Musculação",
                                durationMinutes = obj.get("durationMinutes")?.takeIf { !it.isJsonNull }?.asInt ?: 45,
                                caloriesBurned = obj.get("caloriesBurned")?.takeIf { !it.isJsonNull }?.asDouble ?: 300.0,
                                notes = obj.get("notes")?.takeIf { !it.isJsonNull }?.asString ?: "",
                                workoutDate = parseIsoMillis(obj.get("workoutDate")?.takeIf { !it.isJsonNull }?.asString)
                            )
                        )
                    }

                    root.getAsJsonArray("waters")?.forEach { elem ->
                        val obj = elem.asJsonObject
                        val id = obj.get("id")?.takeIf { !it.isJsonNull }?.asString ?: return@forEach
                        db.insertWater(
                            WaterEntry(
                                id = id,
                                milliliters = obj.get("milliliters")?.takeIf { !it.isJsonNull }?.asInt ?: 250,
                                entryDate = parseIsoMillis(obj.get("entryDate")?.takeIf { !it.isJsonNull }?.asString)
                            )
                        )
                    }

                    root.getAsJsonArray("weights")?.forEach { elem ->
                        val obj = elem.asJsonObject
                        val id = obj.get("id")?.takeIf { !it.isJsonNull }?.asString ?: return@forEach
                        db.insertWeight(
                            WeightEntry(
                                id = id,
                                weight = obj.get("weight")?.takeIf { !it.isJsonNull }?.asDouble ?: 70.0,
                                entryDate = parseIsoMillis(obj.get("entryDate")?.takeIf { !it.isJsonNull }?.asString)
                            )
                        )
                    }
                } catch (_: Exception) {
                }
                refreshAllFlowsFromDb()
            }
            Result.success(Unit)
        } else {
            val errMsg = res.exceptionOrNull()?.message ?: ""
            if (errMsg.contains("accountDeleted")) {
                logout()
            }
            Result.failure(res.exceptionOrNull() ?: Exception("Sync pull failed"))
        }
    }

    private fun cleanJson(raw: String): String {
        var clean = raw.trim()
        if (clean.startsWith("```json")) {
            clean = clean.removePrefix("```json")
        } else if (clean.startsWith("```")) {
            clean = clean.removePrefix("```")
        }
        if (clean.endsWith("```")) {
            clean = clean.removeSuffix("```")
        }
        return clean.trim()
    }
}
