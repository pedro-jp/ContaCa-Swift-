package com.contaca.app.data.local

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.contaca.app.data.model.*
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

class DatabaseHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    private val gson = Gson()

    companion object {
        private const val DATABASE_NAME = "contaca.db"
        private const val DATABASE_VERSION = 1

        private const val TABLE_PROFILE = "profile"
        private const val TABLE_FOODS = "foods"
        private const val TABLE_WORKOUTS = "workouts"
        private const val TABLE_WATERS = "waters"
        private const val TABLE_WEIGHTS = "weights"
        private const val TABLE_ROUTINES = "routines"
        private const val TABLE_ANALYSES = "analyses"
        private const val TABLE_ACTIVITY_LOGS = "activity_logs"
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("""
            CREATE TABLE $TABLE_PROFILE (
                id INTEGER PRIMARY KEY,
                name TEXT,
                email TEXT,
                goal TEXT,
                target_calories REAL,
                target_burn REAL,
                target_steps REAL,
                current_weight REAL,
                target_weight REAL,
                height REAL,
                target_protein REAL,
                target_fat REAL,
                target_carbs REAL,
                target_water INTEGER
            )
        """)

        db.execSQL("""
            CREATE TABLE $TABLE_FOODS (
                id TEXT PRIMARY KEY,
                name TEXT,
                brand TEXT,
                meal_type TEXT,
                portion_grams REAL,
                calories REAL,
                protein REAL,
                carbohydrates REAL,
                fat REAL,
                consumed_at INTEGER
            )
        """)

        db.execSQL("""
            CREATE TABLE $TABLE_WORKOUTS (
                id TEXT PRIMARY KEY,
                title TEXT,
                workout_type TEXT,
                duration_minutes INTEGER,
                calories_burned REAL,
                notes TEXT,
                workout_date INTEGER
            )
        """)

        db.execSQL("""
            CREATE TABLE $TABLE_WATERS (
                id TEXT PRIMARY KEY,
                milliliters INTEGER,
                entry_date INTEGER
            )
        """)

        db.execSQL("""
            CREATE TABLE $TABLE_WEIGHTS (
                id TEXT PRIMARY KEY,
                weight REAL,
                entry_date INTEGER,
                notes TEXT
            )
        """)

        db.execSQL("""
            CREATE TABLE $TABLE_ROUTINES (
                id TEXT PRIMARY KEY,
                title TEXT,
                workout_type TEXT,
                target_muscles TEXT,
                hypertrophy_focus TEXT,
                estimated_duration INTEGER,
                estimated_calories REAL,
                recommended_rest INTEGER,
                is_favorite INTEGER,
                exercises_json TEXT,
                notes TEXT,
                created_at INTEGER
            )
        """)

        db.execSQL("""
            CREATE TABLE $TABLE_ANALYSES (
                id TEXT PRIMARY KEY,
                status_summary TEXT,
                calorie_diagnostic TEXT,
                macro_diagnostic TEXT,
                hydration_diagnostic TEXT,
                workout_suggestions_json TEXT,
                nutrition_suggestions_json TEXT,
                weekly_action_plan TEXT,
                suggested_targets_json TEXT,
                recommended_routine_json TEXT,
                generated_at INTEGER
            )
        """)

        db.execSQL("""
            CREATE TABLE $TABLE_ACTIVITY_LOGS (
                id TEXT PRIMARY KEY,
                timestamp TEXT,
                category TEXT,
                title TEXT,
                is_snack INTEGER,
                calories_change REAL,
                protein_grams REAL,
                carbs_grams REAL,
                fat_grams REAL,
                water_milliliters INTEGER,
                weight_kg REAL,
                details TEXT
            )
        """)

        // Insere perfil padrão
        val cv = ContentValues().apply {
            put("id", 1)
            put("name", "João Pedro")
            put("email", "joaopedroc035@gmail.com")
            put("goal", "GAIN")
            put("target_calories", 2800.0)
            put("target_burn", 600.0)
            put("target_steps", 8000.0)
            put("current_weight", 72.0)
            put("target_weight", 80.0)
            put("height", 1.78)
            put("target_protein", 160.0)
            put("target_fat", 70.0)
            put("target_carbs", 380.0)
            put("target_water", 2500)
        }
        db.insert(TABLE_PROFILE, null, cv)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Upgrade se necessário
    }

    // --- Profile ---
    fun getProfile(): UserProfile {
        val db = readableDatabase
        val cursor = db.query(TABLE_PROFILE, null, "id = 1", null, null, null, null)
        cursor.use {
            if (it.moveToFirst()) {
                val goalStr = it.getString(it.getColumnIndexOrThrow("goal")) ?: "GAIN"
                val goal = try { FitnessGoal.valueOf(goalStr) } catch (_: Exception) { FitnessGoal.GAIN }
                return UserProfile(
                    name = it.getString(it.getColumnIndexOrThrow("name")) ?: "João Pedro",
                    email = it.getString(it.getColumnIndexOrThrow("email")) ?: "joao@email.com",
                    goal = goal,
                    targetCalorieIntake = it.getDouble(it.getColumnIndexOrThrow("target_calories")),
                    targetCalorieBurn = it.getDouble(it.getColumnIndexOrThrow("target_burn")),
                    targetSteps = it.getDouble(it.getColumnIndexOrThrow("target_steps")),
                    currentWeight = it.getDouble(it.getColumnIndexOrThrow("current_weight")),
                    targetWeight = it.getDouble(it.getColumnIndexOrThrow("target_weight")),
                    heightMeters = it.getDouble(it.getColumnIndexOrThrow("height")),
                    targetProtein = it.getDouble(it.getColumnIndexOrThrow("target_protein")),
                    targetFat = it.getDouble(it.getColumnIndexOrThrow("target_fat")),
                    targetCarbohydrates = it.getDouble(it.getColumnIndexOrThrow("target_carbs")),
                    targetWaterMilliliters = it.getInt(it.getColumnIndexOrThrow("target_water"))
                )
            }
        }
        return UserProfile()
    }

    fun saveProfile(profile: UserProfile) {
        val db = writableDatabase
        val cv = ContentValues().apply {
            put("name", profile.name)
            put("email", profile.email)
            put("goal", profile.goal.name)
            put("target_calories", profile.targetCalorieIntake)
            put("target_burn", profile.targetCalorieBurn)
            put("target_steps", profile.targetSteps)
            put("current_weight", profile.currentWeight)
            put("target_weight", profile.targetWeight)
            put("height", profile.heightMeters)
            put("target_protein", profile.targetProtein)
            put("target_fat", profile.targetFat)
            put("target_carbs", profile.targetCarbohydrates)
            put("target_water", profile.targetWaterMilliliters)
        }
        db.update(TABLE_PROFILE, cv, "id = 1", null)
    }

    // --- Foods ---
    fun insertFood(food: FoodEntry) {
        val db = writableDatabase
        val cv = ContentValues().apply {
            put("id", food.id)
            put("name", food.name)
            put("brand", food.brand)
            put("meal_type", food.mealType.name)
            put("portion_grams", food.portionGrams)
            put("calories", food.calories)
            put("protein", food.protein)
            put("carbohydrates", food.carbohydrates)
            put("fat", food.fat)
            put("consumed_at", food.consumedAt)
        }
        db.insertWithOnConflict(TABLE_FOODS, null, cv, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun getAllFoods(): List<FoodEntry> {
        val db = readableDatabase
        val list = mutableListOf<FoodEntry>()
        val cursor = db.query(TABLE_FOODS, null, null, null, null, null, "consumed_at DESC")
        cursor.use {
            while (it.moveToNext()) {
                val mtStr = it.getString(it.getColumnIndexOrThrow("meal_type")) ?: "LUNCH"
                val mealType = try { MealType.valueOf(mtStr) } catch (_: Exception) { MealType.LUNCH }
                list.add(
                    FoodEntry(
                        id = it.getString(it.getColumnIndexOrThrow("id")),
                        name = it.getString(it.getColumnIndexOrThrow("name")),
                        brand = it.getString(it.getColumnIndexOrThrow("brand")) ?: "",
                        mealType = mealType,
                        portionGrams = it.getDouble(it.getColumnIndexOrThrow("portion_grams")),
                        calories = it.getDouble(it.getColumnIndexOrThrow("calories")),
                        protein = it.getDouble(it.getColumnIndexOrThrow("protein")),
                        carbohydrates = it.getDouble(it.getColumnIndexOrThrow("carbohydrates")),
                        fat = it.getDouble(it.getColumnIndexOrThrow("fat")),
                        consumedAt = it.getLong(it.getColumnIndexOrThrow("consumed_at"))
                    )
                )
            }
        }
        return list
    }

    fun deleteFood(id: String) {
        writableDatabase.delete(TABLE_FOODS, "id = ?", arrayOf(id))
    }

    // --- Workouts ---
    fun insertWorkout(workout: WorkoutEntry) {
        val db = writableDatabase
        val cv = ContentValues().apply {
            put("id", workout.id)
            put("title", workout.title)
            put("workout_type", workout.workoutType)
            put("duration_minutes", workout.durationMinutes)
            put("calories_burned", workout.caloriesBurned)
            put("notes", workout.notes)
            put("workout_date", workout.workoutDate)
        }
        db.insertWithOnConflict(TABLE_WORKOUTS, null, cv, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun getAllWorkouts(): List<WorkoutEntry> {
        val db = readableDatabase
        val list = mutableListOf<WorkoutEntry>()
        val cursor = db.query(TABLE_WORKOUTS, null, null, null, null, null, "workout_date DESC")
        cursor.use {
            while (it.moveToNext()) {
                list.add(
                    WorkoutEntry(
                        id = it.getString(it.getColumnIndexOrThrow("id")),
                        title = it.getString(it.getColumnIndexOrThrow("title")),
                        workoutType = it.getString(it.getColumnIndexOrThrow("workout_type")),
                        durationMinutes = it.getInt(it.getColumnIndexOrThrow("duration_minutes")),
                        caloriesBurned = it.getDouble(it.getColumnIndexOrThrow("calories_burned")),
                        notes = it.getString(it.getColumnIndexOrThrow("notes")) ?: "",
                        workoutDate = it.getLong(it.getColumnIndexOrThrow("workout_date"))
                    )
                )
            }
        }
        return list
    }

    fun deleteWorkout(id: String) {
        writableDatabase.delete(TABLE_WORKOUTS, "id = ?", arrayOf(id))
    }

    // --- Water ---
    fun insertWater(water: WaterEntry) {
        val db = writableDatabase
        val cv = ContentValues().apply {
            put("id", water.id)
            put("milliliters", water.milliliters)
            put("entry_date", water.entryDate)
        }
        db.insertWithOnConflict(TABLE_WATERS, null, cv, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun getAllWaters(): List<WaterEntry> {
        val db = readableDatabase
        val list = mutableListOf<WaterEntry>()
        val cursor = db.query(TABLE_WATERS, null, null, null, null, null, "entry_date DESC")
        cursor.use {
            while (it.moveToNext()) {
                list.add(
                    WaterEntry(
                        id = it.getString(it.getColumnIndexOrThrow("id")),
                        milliliters = it.getInt(it.getColumnIndexOrThrow("milliliters")),
                        entryDate = it.getLong(it.getColumnIndexOrThrow("entry_date"))
                    )
                )
            }
        }
        return list
    }

    // --- Weights ---
    fun insertWeight(weight: WeightEntry) {
        val db = writableDatabase
        val cv = ContentValues().apply {
            put("id", weight.id)
            put("weight", weight.weight)
            put("entry_date", weight.entryDate)
            put("notes", weight.notes)
        }
        db.insertWithOnConflict(TABLE_WEIGHTS, null, cv, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun getAllWeights(): List<WeightEntry> {
        val db = readableDatabase
        val list = mutableListOf<WeightEntry>()
        val cursor = db.query(TABLE_WEIGHTS, null, null, null, null, null, "entry_date DESC")
        cursor.use {
            while (it.moveToNext()) {
                list.add(
                    WeightEntry(
                        id = it.getString(it.getColumnIndexOrThrow("id")),
                        weight = it.getDouble(it.getColumnIndexOrThrow("weight")),
                        entryDate = it.getLong(it.getColumnIndexOrThrow("entry_date")),
                        notes = it.getString(it.getColumnIndexOrThrow("notes")) ?: ""
                    )
                )
            }
        }
        return list
    }

    // --- Routines ---
    fun insertRoutine(routine: WorkoutRoutine) {
        val db = writableDatabase
        val cv = ContentValues().apply {
            put("id", routine.id)
            put("title", routine.title)
            put("workout_type", routine.workoutType)
            put("target_muscles", routine.targetMuscles)
            put("hypertrophy_focus", routine.hypertrophyFocus)
            put("estimated_duration", routine.estimatedDurationMinutes)
            put("estimated_calories", routine.estimatedCalories)
            put("recommended_rest", routine.recommendedRestSeconds)
            put("is_favorite", if (routine.isFavorite) 1 else 0)
            put("exercises_json", gson.toJson(routine.exercises))
            put("notes", routine.notes)
            put("created_at", routine.createdAt)
        }
        db.insertWithOnConflict(TABLE_ROUTINES, null, cv, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun getAllRoutines(): List<WorkoutRoutine> {
        val db = readableDatabase
        val list = mutableListOf<WorkoutRoutine>()
        val cursor = db.query(TABLE_ROUTINES, null, null, null, null, null, "created_at DESC")
        cursor.use {
            val type = object : TypeToken<List<WorkoutExerciseItem>>() {}.type
            while (it.moveToNext()) {
                val json = it.getString(it.getColumnIndexOrThrow("exercises_json")) ?: "[]"
                val exercises: List<WorkoutExerciseItem> = try { gson.fromJson(json, type) } catch (_: Exception) { emptyList() }
                list.add(
                    WorkoutRoutine(
                        id = it.getString(it.getColumnIndexOrThrow("id")),
                        title = it.getString(it.getColumnIndexOrThrow("title")),
                        workoutType = it.getString(it.getColumnIndexOrThrow("workout_type")),
                        targetMuscles = it.getString(it.getColumnIndexOrThrow("target_muscles")) ?: "",
                        hypertrophyFocus = it.getString(it.getColumnIndexOrThrow("hypertrophy_focus")) ?: "",
                        estimatedDurationMinutes = it.getInt(it.getColumnIndexOrThrow("estimated_duration")),
                        estimatedCalories = it.getDouble(it.getColumnIndexOrThrow("estimated_calories")),
                        recommendedRestSeconds = it.getInt(it.getColumnIndexOrThrow("recommended_rest")),
                        isFavorite = it.getInt(it.getColumnIndexOrThrow("is_favorite")) == 1,
                        exercises = exercises,
                        notes = it.getString(it.getColumnIndexOrThrow("notes")) ?: "",
                        createdAt = it.getLong(it.getColumnIndexOrThrow("created_at"))
                    )
                )
            }
        }
        return list
    }

    // --- Analyses ---
    fun insertAnalysis(analysis: EvolutionAIAnalysis) {
        val db = writableDatabase
        val cv = ContentValues().apply {
            put("id", analysis.id)
            put("status_summary", analysis.statusSummary)
            put("calorie_diagnostic", analysis.calorieDiagnostic)
            put("macro_diagnostic", analysis.macroDiagnostic)
            put("hydration_diagnostic", analysis.hydrationDiagnostic)
            put("workout_suggestions_json", gson.toJson(analysis.workoutSuggestions))
            put("nutrition_suggestions_json", gson.toJson(analysis.nutritionSuggestions))
            put("weekly_action_plan", analysis.weeklyActionPlan)
            put("suggested_targets_json", analysis.suggestedTargets?.let { gson.toJson(it) })
            put("recommended_routine_json", analysis.recommendedRoutine?.let { gson.toJson(it) })
            put("generated_at", analysis.generatedAt)
        }
        db.insertWithOnConflict(TABLE_ANALYSES, null, cv, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun getLatestAnalysis(): EvolutionAIAnalysis? {
        val db = readableDatabase
        val cursor = db.query(TABLE_ANALYSES, null, null, null, null, null, "generated_at DESC", "1")
        cursor.use {
            if (it.moveToFirst()) {
                val listType = object : TypeToken<List<String>>() {}.type
                val wJson = it.getString(it.getColumnIndexOrThrow("workout_suggestions_json")) ?: "[]"
                val nJson = it.getString(it.getColumnIndexOrThrow("nutrition_suggestions_json")) ?: "[]"
                val tJson = it.getString(it.getColumnIndexOrThrow("suggested_targets_json"))
                val rJson = it.getString(it.getColumnIndexOrThrow("recommended_routine_json"))

                return EvolutionAIAnalysis(
                    id = it.getString(it.getColumnIndexOrThrow("id")),
                    statusSummary = it.getString(it.getColumnIndexOrThrow("status_summary")),
                    calorieDiagnostic = it.getString(it.getColumnIndexOrThrow("calorie_diagnostic")),
                    macroDiagnostic = it.getString(it.getColumnIndexOrThrow("macro_diagnostic")),
                    hydrationDiagnostic = it.getString(it.getColumnIndexOrThrow("hydration_diagnostic")),
                    workoutSuggestions = try { gson.fromJson(wJson, listType) } catch (_: Exception) { emptyList() },
                    nutritionSuggestions = try { gson.fromJson(nJson, listType) } catch (_: Exception) { emptyList() },
                    weeklyActionPlan = it.getString(it.getColumnIndexOrThrow("weekly_action_plan")),
                    suggestedTargets = tJson?.let { t -> try { gson.fromJson(t, SuggestedNutritionTargets::class.java) } catch (_: Exception) { null } },
                    recommendedRoutine = rJson?.let { r -> try { gson.fromJson(r, AIRecommendedRoutine::class.java) } catch (_: Exception) { null } },
                    generatedAt = it.getLong(it.getColumnIndexOrThrow("generated_at"))
                )
            }
        }
        return null
    }

    // --- Activity Logs ---
    fun insertActivityLog(log: ActivityLogRecord) {
        val db = writableDatabase
        val cv = ContentValues().apply {
            put("id", log.id)
            put("timestamp", log.timestamp)
            put("category", log.category)
            put("title", log.title)
            put("is_snack", if (log.isSnack == true) 1 else 0)
            put("calories_change", log.caloriesChange)
            log.proteinGrams?.let { put("protein_grams", it) }
            log.carbsGrams?.let { put("carbs_grams", it) }
            log.fatGrams?.let { put("fat_grams", it) }
            log.waterMilliliters?.let { put("water_milliliters", it) }
            log.weightKg?.let { put("weight_kg", it) }
            log.details?.let { put("details", it) }
        }
        db.insertWithOnConflict(TABLE_ACTIVITY_LOGS, null, cv, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun getAllActivityLogs(): List<ActivityLogRecord> {
        val db = readableDatabase
        val list = mutableListOf<ActivityLogRecord>()
        val cursor = db.query(TABLE_ACTIVITY_LOGS, null, null, null, null, null, "timestamp DESC")
        cursor.use {
            while (it.moveToNext()) {
                val isSnack = if (it.isNull(it.getColumnIndexOrThrow("is_snack"))) null else it.getInt(it.getColumnIndexOrThrow("is_snack")) == 1
                val prot = if (it.isNull(it.getColumnIndexOrThrow("protein_grams"))) null else it.getDouble(it.getColumnIndexOrThrow("protein_grams"))
                val carbs = if (it.isNull(it.getColumnIndexOrThrow("carbs_grams"))) null else it.getDouble(it.getColumnIndexOrThrow("carbs_grams"))
                val fat = if (it.isNull(it.getColumnIndexOrThrow("fat_grams"))) null else it.getDouble(it.getColumnIndexOrThrow("fat_grams"))
                val water = if (it.isNull(it.getColumnIndexOrThrow("water_milliliters"))) null else it.getInt(it.getColumnIndexOrThrow("water_milliliters"))
                val weight = if (it.isNull(it.getColumnIndexOrThrow("weight_kg"))) null else it.getDouble(it.getColumnIndexOrThrow("weight_kg"))
                val details = it.getString(it.getColumnIndexOrThrow("details"))

                list.add(
                    ActivityLogRecord(
                        id = it.getString(it.getColumnIndexOrThrow("id")),
                        timestamp = it.getString(it.getColumnIndexOrThrow("timestamp")),
                        category = it.getString(it.getColumnIndexOrThrow("category")),
                        title = it.getString(it.getColumnIndexOrThrow("title")),
                        isSnack = isSnack,
                        caloriesChange = it.getDouble(it.getColumnIndexOrThrow("calories_change")),
                        proteinGrams = prot,
                        carbsGrams = carbs,
                        fatGrams = fat,
                        waterMilliliters = water,
                        weightKg = weight,
                        details = details
                    )
                )
            }
        }
        return list
    }

    fun clearAllUserData(defaultName: String = "Usuário", defaultEmail: String = "") {
        val db = writableDatabase
        db.beginTransaction()
        try {
            db.delete(TABLE_FOODS, null, null)
            db.delete(TABLE_WORKOUTS, null, null)
            db.delete(TABLE_WATERS, null, null)
            db.delete(TABLE_WEIGHTS, null, null)
            db.delete(TABLE_ROUTINES, null, null)
            db.delete(TABLE_ANALYSES, null, null)
            db.delete(TABLE_ACTIVITY_LOGS, null, null)
            db.delete(TABLE_PROFILE, null, null)
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
        saveProfile(UserProfile(name = defaultName, email = defaultEmail))
    }
}
