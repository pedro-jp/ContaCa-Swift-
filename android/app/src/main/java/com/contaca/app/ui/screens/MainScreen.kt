package com.contaca.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.contaca.app.data.repository.ContaCaRepository
import com.contaca.app.ui.island.DynamicIslandOverlayService
import com.contaca.app.ui.island.DynamicIslandState
import com.contaca.app.ui.island.DynamicIslandView
import com.contaca.app.ui.theme.DarkSurface
import com.contaca.app.ui.theme.PrimaryGreen
import kotlinx.coroutines.launch

sealed class BottomNavTab(val route: String, val title: String, val icon: ImageVector) {
    object Home : BottomNavTab("home", "Início", Icons.Default.Home)
    object Nutrition : BottomNavTab("nutrition", "Alimentação", Icons.Default.Restaurant)
    object Workouts : BottomNavTab("workouts", "Treinos", Icons.Default.FitnessCenter)
    object Evolution : BottomNavTab("evolution", "Evolução", Icons.Default.TrendingUp)
    object Profile : BottomNavTab("profile", "Ajustes", Icons.Default.Settings)
}

@Composable
fun MainScreen(
    repository: ContaCaRepository,
    islandState: DynamicIslandState,
    onLogout: () -> Unit
) {
    val coroutineScope = rememberCoroutineScope()
    var selectedTab by remember { mutableStateOf<BottomNavTab>(BottomNavTab.Home) }

    val tabs = listOf(
        BottomNavTab.Home,
        BottomNavTab.Nutrition,
        BottomNavTab.Workouts,
        BottomNavTab.Evolution,
        BottomNavTab.Profile
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF030712))
    ) {
        Scaffold(
            containerColor = Color.Transparent,
            bottomBar = {
                NavigationBar(
                    containerColor = DarkSurface,
                    contentColor = Color.White,
                    tonalElevation = 8.dp
                ) {
                    tabs.forEach { tab ->
                        val isSelected = selectedTab == tab
                        NavigationBarItem(
                            selected = isSelected,
                            onClick = { selectedTab = tab },
                            icon = {
                                Icon(
                                    imageVector = tab.icon,
                                    contentDescription = tab.title,
                                    tint = if (isSelected) PrimaryGreen else Color(0xFF64748B)
                                )
                            },
                            label = {
                                Text(
                                    text = tab.title,
                                    color = if (isSelected) PrimaryGreen else Color(0xFF64748B),
                                    fontSize = 10.sp
                                )
                            },
                            colors = NavigationBarItemDefaults.colors(
                                indicatorColor = PrimaryGreen.copy(alpha = 0.15f)
                            )
                        )
                    }
                }
            }
        ) { innerPadding ->
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
            ) {
                when (selectedTab) {
                    BottomNavTab.Home -> HomeScreen(
                        repository = repository,
                        onNavigateToNutrition = { selectedTab = BottomNavTab.Nutrition },
                        onNavigateToWorkouts = { selectedTab = BottomNavTab.Workouts },
                        onStartWorkout = {
                            selectedTab = BottomNavTab.Workouts
                        }
                    )
                    BottomNavTab.Nutrition -> NutritionScreen(repository = repository)
                    BottomNavTab.Workouts -> WorkoutsScreen(repository = repository)
                    BottomNavTab.Evolution -> EvolutionScreen(repository = repository)
                    BottomNavTab.Profile -> ProfileAndIslandScreen(
                        repository = repository,
                        islandState = islandState,
                        onLogout = onLogout
                    )
                }
            }
        }

        // DYNAMIC ISLAND OVERLAY (renders above everything at the top of the window when system overlay service is not active)
        val isOverlayRunning by DynamicIslandOverlayService.isServiceRunning.collectAsState()
        if (!isOverlayRunning) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.TopCenter)
            ) {
                DynamicIslandView(
                    isInsideOverlayService = false,
                    onQuickAddWater = {
                        coroutineScope.launch {
                            repository.addWater(250)
                        }
                    }
                )
            }
        }
    }
}
