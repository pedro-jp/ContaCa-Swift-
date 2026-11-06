package com.forma.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.forma.app.ui.island.DynamicIslandOverlayService
import com.forma.app.ui.island.DynamicIslandState
import com.forma.app.ui.screens.LoginScreen
import com.forma.app.ui.screens.MainScreen
import com.forma.app.ui.screens.SplashScreen
import com.forma.app.ui.theme.FormaTheme
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    private val requestNotificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { _ ->
        // Handled
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val app = application as FormaApplication
        val repository = app.repository
        val islandState = DynamicIslandState.getInstance(this)

        // Observe repository state to update Dynamic Island
        lifecycleScope.launch {
            repository.isWorkoutActive.collectLatest { isActive ->
                val duration = repository.workoutDurationSeconds.value
                val calories = (duration * 0.12)
                if (isActive) {
                    islandState.startWorkout(repository.activeWorkoutName.value)
                    islandState.updateWorkoutProgress(duration, calories)
                } else {
                    islandState.stopWorkout()
                }
            }
        }

        lifecycleScope.launch {
            repository.workoutDurationSeconds.collectLatest { duration ->
                if (repository.isWorkoutActive.value) {
                    val calories = (duration * 0.12)
                    islandState.updateWorkoutProgress(duration, calories)
                }
            }
        }

        lifecycleScope.launch {
            repository.dailySummary.collectLatest { summary ->
                val profile = repository.userProfile.value
                val remaining = (profile.targetCalorieIntake - summary.totalCalories).toInt().coerceAtLeast(0)
                islandState.updateNutritionState(
                    water = summary.totalWaterMl,
                    targetWater = profile.targetWaterMilliliters,
                    remainingCalories = remaining
                )
            }
        }

        checkNotificationPermission()

        if (DynamicIslandOverlayService.canDrawOverlays(this)) {
            DynamicIslandOverlayService.start(this)
        }

        setContent {
            FormaTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    val navController = rememberNavController()

                    NavHost(
                        navController = navController,
                        startDestination = "splash"
                    ) {
                        composable("splash") {
                            SplashScreen(
                                onFinished = {
                                    val isLogged = repository.isLoggedIn()
                                    if (isLogged) {
                                        navController.navigate("main") {
                                            popUpTo("splash") { inclusive = true }
                                        }
                                    } else {
                                        navController.navigate("login") {
                                            popUpTo("splash") { inclusive = true }
                                        }
                                    }
                                }
                            )
                        }

                        composable("login") {
                            LoginScreen(
                                repository = repository,
                                onLoginSuccess = {
                                    navController.navigate("main") {
                                        popUpTo("login") { inclusive = true }
                                    }
                                }
                            )
                        }

                        composable("main") {
                            MainScreen(
                                repository = repository,
                                islandState = islandState,
                                onLogout = {
                                    navController.navigate("login") {
                                        popUpTo("main") { inclusive = true }
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private fun checkNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val hasPermission = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED

            if (!hasPermission) {
                requestNotificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }
}
