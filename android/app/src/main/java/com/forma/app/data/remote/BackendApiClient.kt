package com.forma.app.data.remote

import android.content.Context
import com.forma.app.R
import com.forma.app.data.model.*
import com.google.gson.Gson
import com.google.gson.JsonObject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit

class BackendApiClient(private val context: Context) {

    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    private val gson = Gson()
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    private val prefs by lazy {
        context.getSharedPreferences("forma_prefs", Context.MODE_PRIVATE)
    }

    private val defaultBaseUrl: String by lazy {
        runCatching { context.getString(R.string.backend_base_url).trimEnd('/') }
            .getOrDefault("http://10.0.2.2:8085")
    }

    var baseUrl: String
        get() = prefs.getString("server_base_url", defaultBaseUrl) ?: defaultBaseUrl
        set(value) = prefs.edit().putString("server_base_url", value.trimEnd('/')).apply()

    var jwtToken: String?
        get() = prefs.getString("jwt_token", null)
        set(value) = prefs.edit().putString("jwt_token", value).apply()

    var userId: String?
        get() = prefs.getString("user_id", null)
        set(value) = prefs.edit().putString("user_id", value).apply()

    var userEmail: String?
        get() = prefs.getString("user_email", null)
        set(value) = prefs.edit().putString("user_email", value).apply()

    var userName: String?
        get() = prefs.getString("user_name", null)
        set(value) = prefs.edit().putString("user_name", value).apply()

    var isGuest: Boolean
        get() = prefs.getBoolean("is_guest", false)
        set(value) = prefs.edit().putBoolean("is_guest", value).apply()

    val isAuthenticated: Boolean
        get() = !jwtToken.isNullOrBlank() && !userId.isNullOrBlank()

    fun logout() {
        prefs.edit().clear().apply()
    }

    suspend fun login(email: String, pass: String): Result<String> = withContext(Dispatchers.IO) {
        try {
            val json = JsonObject().apply {
                addProperty("email", email.trim().lowercase())
                addProperty("password", pass.trim())
            }
            val req = Request.Builder()
                .url("$baseUrl/api/auth/login")
                .post(json.toString().toRequestBody(jsonMediaType))
                .build()

            val res = client.newCall(req).execute()
            val body = res.body?.string() ?: ""
            if (!res.isSuccessful) {
                return@withContext Result.failure(Exception("Falha no login (${res.code}): $body"))
            }

            parseAuthSuccess(body)
            Result.success("Login realizado com sucesso")
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun register(name: String, email: String, pass: String): Result<String> = withContext(Dispatchers.IO) {
        try {
            val json = JsonObject().apply {
                addProperty("name", name.trim())
                addProperty("email", email.trim().lowercase())
                addProperty("password", pass.trim())
            }
            val req = Request.Builder()
                .url("$baseUrl/api/auth/register")
                .post(json.toString().toRequestBody(jsonMediaType))
                .build()

            val res = client.newCall(req).execute()
            val body = res.body?.string() ?: ""
            if (!res.isSuccessful) {
                return@withContext Result.failure(Exception("Falha no cadastro (${res.code}): $body"))
            }

            parseAuthSuccess(body)
            Result.success("Cadastro realizado com sucesso")
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun loginSocial(provider: String, providerId: String, email: String, name: String): Result<String> = withContext(Dispatchers.IO) {
        try {
            val json = JsonObject().apply {
                addProperty("provider", provider.uppercase())
                addProperty("providerId", providerId)
                addProperty("email", email.trim().lowercase())
                addProperty("name", name.trim())
            }
            val req = Request.Builder()
                .url("$baseUrl/api/auth/social")
                .post(json.toString().toRequestBody(jsonMediaType))
                .build()

            val res = client.newCall(req).execute()
            val body = res.body?.string() ?: ""
            if (!res.isSuccessful) {
                return@withContext Result.failure(Exception("Falha no login social (${res.code}): $body"))
            }

            parseAuthSuccess(body)
            Result.success("Autenticado com $provider com sucesso")
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    private fun parseAuthSuccess(jsonBody: String) {
        val root = gson.fromJson(jsonBody, JsonObject::class.java)
        jwtToken = root.get("token")?.asString
        userId = root.get("userId")?.asString
        userEmail = root.get("email")?.asString
        userName = root.get("name")?.asString
        isGuest = false
    }

    // --- Sync Push ---
    suspend fun pushSyncData(
        profile: UserProfile,
        foods: List<FoodEntry>,
        workouts: List<WorkoutEntry>,
        waters: List<WaterEntry>,
        weights: List<WeightEntry>,
        routines: List<WorkoutRoutine>,
        analyses: List<EvolutionAIAnalysis>,
        activityLogs: List<ActivityLogRecord>,
        clientResetAckEpochMs: Long? = null
    ): Result<String> = withContext(Dispatchers.IO) {
        val token = jwtToken ?: return@withContext Result.failure(Exception("Não autenticado"))
        try {
            val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }

            val payload = JsonObject().apply {
                add("profile", JsonObject().apply {
                    addProperty("goal", profile.goal.name)
                    addProperty("targetCalorieIntake", profile.targetCalorieIntake)
                    addProperty("targetCalorieBurn", profile.targetCalorieBurn)
                    addProperty("targetSteps", profile.targetSteps)
                    addProperty("targetWeight", profile.targetWeight)
                    addProperty("targetProtein", profile.targetProtein)
                    addProperty("targetCarbohydrates", profile.targetCarbohydrates)
                    addProperty("targetFat", profile.targetFat)
                    addProperty("targetWaterMilliliters", profile.targetWaterMilliliters)
                    addProperty("heightMeters", profile.heightMeters)
                    addProperty("currentWeight", profile.currentWeight)
                })

                add("foods", gson.toJsonTree(foods.map {
                    mapOf(
                        "id" to it.id,
                        "name" to it.name,
                        "brand" to it.brand,
                        "mealType" to it.mealType.title,
                        "portionGrams" to it.portionGrams,
                        "calories" to it.calories,
                        "protein" to it.protein,
                        "carbohydrates" to it.carbohydrates,
                        "fat" to it.fat,
                        "consumedAt" to isoFormat.format(Date(it.consumedAt))
                    )
                }))

                add("workouts", gson.toJsonTree(workouts.map {
                    mapOf(
                        "id" to it.id,
                        "title" to it.title,
                        "workoutType" to it.workoutType,
                        "durationMinutes" to it.durationMinutes,
                        "caloriesBurned" to it.caloriesBurned,
                        "notes" to it.notes,
                        "workoutDate" to isoFormat.format(Date(it.workoutDate))
                    )
                }))

                add("waters", gson.toJsonTree(waters.map {
                    mapOf(
                        "id" to it.id,
                        "milliliters" to it.milliliters,
                        "entryDate" to isoFormat.format(Date(it.entryDate))
                    )
                }))

                add("weights", gson.toJsonTree(weights.map {
                    mapOf(
                        "id" to it.id,
                        "weight" to it.weight,
                        "entryDate" to isoFormat.format(Date(it.entryDate))
                    )
                }))

                add("routines", gson.toJsonTree(routines.map {
                    mapOf(
                        "id" to it.id,
                        "title" to it.title,
                        "workoutType" to it.workoutType,
                        "targetMuscles" to it.targetMuscles,
                        "hypertrophyFocus" to it.hypertrophyFocus,
                        "estimatedDurationMinutes" to it.estimatedDurationMinutes,
                        "estimatedCalories" to it.estimatedCalories,
                        "recommendedRestSeconds" to it.recommendedRestSeconds,
                        "isFavorite" to it.isFavorite,
                        "exercisesJson" to gson.toJson(it.exercises),
                        "notes" to it.notes,
                        "createdAt" to isoFormat.format(Date(it.createdAt))
                    )
                }))

                add("analyses", gson.toJsonTree(analyses.map {
                    mapOf(
                        "id" to it.id,
                        "statusSummary" to it.statusSummary,
                        "calorieDiagnostic" to it.calorieDiagnostic,
                        "macroDiagnostic" to it.macroDiagnostic,
                        "hydrationDiagnostic" to it.hydrationDiagnostic,
                        "workoutSuggestionsJson" to gson.toJson(it.workoutSuggestions),
                        "nutritionSuggestionsJson" to gson.toJson(it.nutritionSuggestions),
                        "weeklyActionPlan" to it.weeklyActionPlan,
                        "suggestedTargetsJson" to it.suggestedTargets?.let { t -> gson.toJson(t) },
                        "recommendedRoutineJson" to it.recommendedRoutine?.let { r -> gson.toJson(r) },
                        "createdAt" to isoFormat.format(Date(it.generatedAt))
                    )
                }))

                add("activityLogs", gson.toJsonTree(activityLogs.map {
                    mapOf(
                        "id" to it.id,
                        "category" to it.category,
                        "title" to it.title,
                        "isSnack" to it.isSnack,
                        "caloriesChange" to it.caloriesChange,
                        "proteinGrams" to it.proteinGrams,
                        "carbsGrams" to it.carbsGrams,
                        "fatGrams" to it.fatGrams,
                        "waterMilliliters" to it.waterMilliliters,
                        "weightKg" to it.weightKg,
                        "details" to it.details,
                        "timestamp" to it.timestamp
                    )
                }))
                if (clientResetAckEpochMs != null && clientResetAckEpochMs > 0L) {
                    addProperty("clientResetAckEpochMs", clientResetAckEpochMs)
                }
            }

            val req = Request.Builder()
                .url("$baseUrl/api/sync/push")
                .header("Authorization", "Bearer $token")
                .post(payload.toString().toRequestBody(jsonMediaType))
                .build()

            val res = client.newCall(req).execute()
            val body = res.body?.string() ?: ""
            if (!res.isSuccessful) {
                return@withContext Result.failure(Exception("Sync Push falhou (${res.code}): $body"))
            }
            Result.success(body)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun pullSyncData(): Result<String> = withContext(Dispatchers.IO) {
        val token = jwtToken ?: return@withContext Result.failure(Exception("Não autenticado"))
        try {
            val req = Request.Builder()
                .url("$baseUrl/api/sync/pull")
                .header("Authorization", "Bearer $token")
                .get()
                .build()

            val res = client.newCall(req).execute()
            val body = res.body?.string() ?: ""
            if (!res.isSuccessful) {
                return@withContext Result.failure(Exception("Sync Pull falhou (${res.code}): $body"))
            }
            Result.success(body)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    // --- AI Proxy Requests ---
    suspend fun analyzeMeal(description: String, userName: String): Result<String> = withContext(Dispatchers.IO) {
        try {
            val json = JsonObject().apply {
                addProperty("description", description)
                addProperty("userName", userName)
            }
            val builder = Request.Builder()
                .url("$baseUrl/api/ai/analyze-meal")
                .post(json.toString().toRequestBody(jsonMediaType))
            jwtToken?.let { builder.header("Authorization", "Bearer $it") }

            val res = client.newCall(builder.build()).execute()
            val body = res.body?.string() ?: ""
            if (!res.isSuccessful) return@withContext Result.failure(Exception("Erro na IA (${res.code}): $body"))
            Result.success(body)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun analyzeWorkout(description: String, userWeight: Double, userName: String): Result<String> = withContext(Dispatchers.IO) {
        try {
            val json = JsonObject().apply {
                addProperty("description", description)
                addProperty("userWeight", userWeight)
                addProperty("userName", userName)
            }
            val builder = Request.Builder()
                .url("$baseUrl/api/ai/analyze-workout")
                .post(json.toString().toRequestBody(jsonMediaType))
            jwtToken?.let { builder.header("Authorization", "Bearer $it") }

            val res = client.newCall(builder.build()).execute()
            val body = res.body?.string() ?: ""
            if (!res.isSuccessful) return@withContext Result.failure(Exception("Erro na IA (${res.code}): $body"))
            Result.success(body)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun analyzeEvolution(
        goal: String,
        weight: Double,
        targetWeight: Double,
        heightMeters: Double,
        targetCalories: Double,
        targetCalorieBurn: Double,
        targetSteps: Double,
        calculatedTmb: Double,
        contextualTdee: Double,
        suggestedBaseCalories: Double,
        avgDailyWorkoutBurn: Double,
        logJson: String,
        userName: String
    ): Result<String> = withContext(Dispatchers.IO) {
        try {
            val json = JsonObject().apply {
                addProperty("userGoal", goal)
                addProperty("currentWeight", weight)
                addProperty("targetWeight", targetWeight)
                addProperty("heightMeters", heightMeters)
                addProperty("targetCalories", targetCalories)
                addProperty("targetCalorieBurn", targetCalorieBurn)
                addProperty("targetSteps", targetSteps)
                addProperty("calculatedTmb", calculatedTmb)
                addProperty("contextualTdee", contextualTdee)
                addProperty("suggestedBaseCalories", suggestedBaseCalories)
                addProperty("avgDailyWorkoutBurn", avgDailyWorkoutBurn)
                addProperty("activityLogJson", logJson)
                addProperty("userName", userName)
            }
            val builder = Request.Builder()
                .url("$baseUrl/api/ai/analyze-evolution")
                .post(json.toString().toRequestBody(jsonMediaType))
            jwtToken?.let { builder.header("Authorization", "Bearer $it") }

            val res = client.newCall(builder.build()).execute()
            val body = res.body?.string() ?: ""
            if (!res.isSuccessful) return@withContext Result.failure(Exception("Erro na IA (${res.code}): $body"))
            Result.success(body)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
