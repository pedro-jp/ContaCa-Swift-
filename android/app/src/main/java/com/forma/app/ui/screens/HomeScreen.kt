package com.forma.app.ui.screens

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.forma.app.R
import com.forma.app.data.model.FitnessGoal
import com.forma.app.data.repository.FormaRepository
import com.forma.app.ui.theme.DarkCard
import com.forma.app.ui.theme.PrimaryGreen
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

enum class HomeFocusMetric {
    CONSUMED, BURNED
}

@Composable
fun HomeScreen(
    repository: FormaRepository,
    onNavigateToNutrition: () -> Unit,
    onNavigateToWorkouts: () -> Unit,
    onStartWorkout: () -> Unit
) {
    val coroutineScope = rememberCoroutineScope()
    val userProfile by repository.userProfile.collectAsState()
    val dailySummary by repository.dailySummary.collectAsState()
    val isWorkoutActive by repository.isWorkoutActive.collectAsState()
    val workoutDurationSeconds by repository.workoutDurationSeconds.collectAsState()

    var activeMetric by remember { mutableStateOf(HomeFocusMetric.CONSUMED) }

    // Calorias consumidas & metas
    val caloriasConsumidas = dailySummary.totalCalories.toDouble()
    val caloriasGastasAtivas = dailySummary.totalBurnedCalories.toDouble()
    val metaCaloriasBase = userProfile.targetCalorieIntake
    val metaCaloriasAjustada = metaCaloriasBase + caloriasGastasAtivas
    val caloriasRestantes = (metaCaloriasAjustada - caloriasConsumidas).toInt()

    val percentualPrincipal = if (activeMetric == HomeFocusMetric.CONSUMED) {
        if (metaCaloriasAjustada > 0) ((caloriasConsumidas / metaCaloriasAjustada) * 100).toInt() else 0
    } else {
        val metaGasto = userProfile.targetCalorieBurn
        if (metaGasto > 0) ((caloriasGastasAtivas / metaGasto) * 100).toInt() else 0
    }

    val progressFloat = (percentualPrincipal.toFloat() / 100f).coerceIn(0f, 1f)
    val animatedProgress by animateFloatAsState(targetValue = progressFloat, animationSpec = tween(600), label = "progress")

    // Água
    val currentWater = dailySummary.totalWaterMl
    val targetWater = userProfile.targetWaterMilliliters
    val waterRatio = if (targetWater > 0) (currentWater.toFloat() / targetWater.toFloat()).coerceIn(0f, 1f) else 0f

    // Saudação dinâmica idêntica ao iOS
    val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
    val saudacao = when (hour) {
        in 5..11 -> "Bom dia"
        in 12..17 -> "Boa tarde"
        else -> "Boa noite"
    }

    val dateFormat = SimpleDateFormat("EEEE, d 'de' MMMM", Locale("pt", "BR"))
    val dataExtenso = dateFormat.format(Date()).replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale("pt", "BR")) else it.toString() }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF030712))
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        Spacer(modifier = Modifier.height(58.dp))

        // HEADER ESTILO IOS (Foto + Saudação + Data + Badge do Objetivo)
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Image(
                painter = painterResource(id = R.drawable.profile),
                contentDescription = "Foto de perfil",
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .border(1.5.dp, Color.White.copy(alpha = 0.1f), CircleShape)
            )

            Spacer(modifier = Modifier.width(14.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "$saudacao, ${userProfile.name.ifEmpty { "João Pedro" }}",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    text = dataExtenso,
                    fontSize = 13.sp,
                    color = Color(0xFF94A3B8)
                )
            }

            // Badge do Objetivo (Ganho / Perda / Manutenção)
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = Color(0xFF183C36),
                modifier = Modifier.padding(start = 6.dp)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = if (userProfile.goal == FitnessGoal.GAIN) Icons.Default.TrendingUp else Icons.Default.TrendingDown,
                        contentDescription = null,
                        tint = Color(0xFF54E1C3),
                        modifier = Modifier.size(13.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = if (userProfile.goal == FitnessGoal.GAIN) "Ganho" else if (userProfile.goal == FitnessGoal.LOSE) "Perda" else "Manutenção",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color(0xFF54E1C3)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(18.dp))

        // Active Workout Banner (if any)
        if (isWorkoutActive) {
            Surface(
                shape = RoundedCornerShape(16.dp),
                color = Color(0xFFEF4444).copy(alpha = 0.15f),
                border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFFEF4444).copy(alpha = 0.4f)),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(12.dp)
                                .clip(CircleShape)
                                .background(Color(0xFFEF4444))
                        )
                        Spacer(modifier = Modifier.width(10.dp))
                        Column {
                            Text(
                                text = "Treino em Andamento!",
                                fontWeight = FontWeight.Bold,
                                color = Color.White,
                                fontSize = 15.sp
                            )
                            val mins = workoutDurationSeconds / 60
                            val secs = workoutDurationSeconds % 60
                            Text(
                                text = String.format("%02d:%02d decorridos • Ilha Ativa", mins, secs),
                                color = Color(0xFFFCA5A5),
                                fontSize = 13.sp
                            )
                        }
                    }

                    Button(
                        onClick = onNavigateToWorkouts,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Color(0xFFEF4444),
                            contentColor = Color.White
                        ),
                        shape = RoundedCornerShape(8.dp),
                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                    ) {
                        Text("Ver", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
        }

        // CARD PRINCIPAL: BALANÇO DIÁRIO COM SELETOR CONSUMIDA / GASTA (Identical to iOS)
        Card(
            shape = RoundedCornerShape(20.dp),
            colors = CardDefaults.cardColors(containerColor = DarkCard),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                // Header do Card
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = if (activeMetric == HomeFocusMetric.CONSUMED) "Balanço Calórico" else "Queima Ativa",
                            fontSize = 17.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                        Text(
                            text = if (activeMetric == HomeFocusMetric.CONSUMED) "Calorias do treino somadas à sua meta" else "Calorias ativas registradas",
                            fontSize = 12.sp,
                            color = Color(0xFF94A3B8)
                        )
                    }

                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = Color(0xFF183C36)
                    ) {
                        Text(
                            text = "$percentualPrincipal%",
                            color = Color(0xFF54E1C3),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(14.dp))

                // Segmented Control (Consumidas / Gastas)
                Surface(
                    shape = RoundedCornerShape(10.dp),
                    color = Color(0xFF0F172A),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(3.dp)
                    ) {
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = if (activeMetric == HomeFocusMetric.CONSUMED) Color(0xFF1E293B) else Color.Transparent,
                            modifier = Modifier
                                .weight(1f)
                                .clickable { activeMetric = HomeFocusMetric.CONSUMED }
                        ) {
                            Text(
                                text = "Consumidas",
                                color = if (activeMetric == HomeFocusMetric.CONSUMED) Color.White else Color(0xFF94A3B8),
                                fontSize = 13.sp,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier
                                    .padding(vertical = 8.dp)
                                    .fillMaxWidth(),
                                textAlign = androidx.compose.ui.text.style.TextAlign.Center
                            )
                        }

                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = if (activeMetric == HomeFocusMetric.BURNED) Color(0xFF1E293B) else Color.Transparent,
                            modifier = Modifier
                                .weight(1f)
                                .clickable { activeMetric = HomeFocusMetric.BURNED }
                        ) {
                            Text(
                                text = "Gastas",
                                color = if (activeMetric == HomeFocusMetric.BURNED) Color.White else Color(0xFF94A3B8),
                                fontSize = 13.sp,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier
                                    .padding(vertical = 8.dp)
                                    .fillMaxWidth(),
                                textAlign = androidx.compose.ui.text.style.TextAlign.Center
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(18.dp))

                // Círculo de Progresso Principal com visual idêntico ao iOS
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(160.dp),
                    contentAlignment = Alignment.Center
                ) {
                    androidx.compose.foundation.Canvas(modifier = Modifier.size(150.dp)) {
                        // Track ring
                        drawCircle(
                            color = Color(0xFF334155).copy(alpha = 0.4f),
                            style = Stroke(width = 12.dp.toPx(), cap = StrokeCap.Round)
                        )
                        // Progress ring
                        drawArc(
                            color = if (activeMetric == HomeFocusMetric.CONSUMED) Color(0xFF54E1C3) else Color(0xFFD4F782),
                            startAngle = -90f,
                            sweepAngle = animatedProgress * 360f,
                            useCenter = false,
                            style = Stroke(width = 12.dp.toPx(), cap = StrokeCap.Round)
                        )
                    }

                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = if (activeMetric == HomeFocusMetric.CONSUMED) "${caloriasConsumidas.toInt()}" else "${caloriasGastasAtivas.toInt()}",
                            fontSize = 32.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = Color.White
                        )
                        Text(
                            text = if (activeMetric == HomeFocusMetric.CONSUMED) "consumidas" else "gastas",
                            fontSize = 12.sp,
                            color = Color(0xFF94A3B8)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(18.dp))

                // Balanço lado a lado: Consumidas, Treino (Saúde) e Saldo Disponível
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    BalanceBox(
                        title = "Consumidas",
                        value = "${caloriasConsumidas.toInt()}",
                        meta = "meta ${metaCaloriasAjustada.toInt()}",
                        color = Color(0xFF54E1C3),
                        icon = Icons.Default.Restaurant,
                        modifier = Modifier.weight(1f)
                    )

                    BalanceBox(
                        title = "Treino (Saúde)",
                        value = "+${caloriasGastasAtivas.toInt()}",
                        meta = "somado",
                        color = Color(0xFFD4F782),
                        icon = Icons.Default.LocalFireDepartment,
                        modifier = Modifier.weight(1f)
                    )

                    BalanceBox(
                        title = "Disponível",
                        value = "$caloriasRestantes",
                        meta = "kcal",
                        color = if (caloriasRestantes >= 0) Color(0xFF54E1C3) else Color(0xFFF97316),
                        icon = Icons.Default.Bolt,
                        modifier = Modifier.weight(1f)
                    )
                }

                Spacer(modifier = Modifier.height(18.dp))
                HorizontalDivider(color = Color.White.copy(alpha = 0.08f))
                Spacer(modifier = Modifier.height(14.dp))

                // Macronutrientes consumidos hoje vs Metas (3 Barras iOS Style)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Macronutrientes",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                    Text(
                        text = "Consumido / Meta",
                        fontSize = 11.sp,
                        color = Color(0xFF94A3B8)
                    )
                }

                Spacer(modifier = Modifier.height(10.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    MacroBarItem(
                        name = "Carboidratos",
                        consumed = dailySummary.totalCarbs,
                        target = userProfile.targetCarbohydrates.toInt(),
                        color = Color(0xFF54E1C3),
                        modifier = Modifier.weight(1f)
                    )
                    MacroBarItem(
                        name = "Proteínas",
                        consumed = dailySummary.totalProtein,
                        target = userProfile.targetProtein.toInt(),
                        color = Color(0xFFD4F782),
                        modifier = Modifier.weight(1f)
                    )
                    MacroBarItem(
                        name = "Gorduras",
                        consumed = dailySummary.totalFat,
                        target = userProfile.targetFat.toInt(),
                        color = Color(0xFFF97316),
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Water Tracking Card
        Card(
            shape = RoundedCornerShape(20.dp),
            colors = CardDefaults.cardColors(containerColor = DarkCard),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(18.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(Color(0xFF0284C7).copy(alpha = 0.2f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.WaterDrop,
                                contentDescription = null,
                                tint = Color(0xFF38BDF8),
                                modifier = Modifier.size(22.dp)
                            )
                        }
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text("Consumo de Água", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 15.sp)
                            Text("$currentWater / $targetWater ml", color = Color(0xFF94A3B8), fontSize = 13.sp)
                        }
                    }

                    // Quick +250ml Button
                    Button(
                        onClick = {
                            coroutineScope.launch {
                                repository.addWater(250)
                            }
                        },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Color(0xFF0284C7),
                            contentColor = Color.White
                        ),
                        shape = RoundedCornerShape(10.dp),
                        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp)
                    ) {
                        Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("+250ml", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                LinearProgressIndicator(
                    progress = { waterRatio.coerceIn(0f, 1f) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(8.dp)
                        .clip(RoundedCornerShape(4.dp)),
                    color = Color(0xFF38BDF8),
                    trackColor = Color(0xFF1E293B)
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Quick Actions Row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Button(
                onClick = onNavigateToNutrition,
                modifier = Modifier
                    .weight(1f)
                    .height(48.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1E293B), contentColor = Color.White)
            ) {
                Icon(Icons.Default.Restaurant, contentDescription = null, modifier = Modifier.size(18.dp), tint = PrimaryGreen)
                Spacer(modifier = Modifier.width(8.dp))
                Text("Adicionar Refeição", fontSize = 13.sp)
            }

            Button(
                onClick = {
                    if (isWorkoutActive) {
                        onNavigateToWorkouts()
                    } else {
                        onStartWorkout()
                    }
                },
                modifier = Modifier
                    .weight(1f)
                    .height(48.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (isWorkoutActive) Color(0xFFDC2626) else PrimaryGreen,
                    contentColor = if (isWorkoutActive) Color.White else Color.Black
                )
            ) {
                Icon(
                    imageVector = if (isWorkoutActive) Icons.Default.Stop else Icons.Default.PlayArrow,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = if (isWorkoutActive) "Ver Treino" else "Iniciar Treino",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }

        Spacer(modifier = Modifier.height(40.dp))
    }
}

@Composable
private fun BalanceBox(
    title: String,
    value: String,
    meta: String,
    color: Color,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    modifier: Modifier = Modifier
) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = Color(0xFF0F172A),
        modifier = modifier
    ) {
        Column(modifier = Modifier.padding(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(imageVector = icon, contentDescription = null, tint = color, modifier = Modifier.size(14.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text(title, fontSize = 11.sp, color = Color(0xFF94A3B8), maxLines = 1)
            }
            Spacer(modifier = Modifier.height(6.dp))
            Text(value, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color.White)
            Text(meta, fontSize = 10.sp, color = Color(0xFF64748B))
        }
    }
}

@Composable
private fun MacroBarItem(
    name: String,
    consumed: Int,
    target: Int,
    color: Color,
    modifier: Modifier = Modifier
) {
    val progress = if (target > 0) (consumed.toFloat() / target.toFloat()).coerceIn(0f, 1f) else 0f

    Surface(
        shape = RoundedCornerShape(12.dp),
        color = Color(0xFF0F172A),
        modifier = modifier
    ) {
        Column(modifier = Modifier.padding(10.dp)) {
            Text(name, fontSize = 11.sp, color = Color(0xFF94A3B8), fontWeight = FontWeight.Medium, maxLines = 1)
            Spacer(modifier = Modifier.height(4.dp))
            Text("${consumed}g", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = Color.White)
            Text("meta ${target}g", fontSize = 10.sp, color = Color(0xFF64748B))
            Spacer(modifier = Modifier.height(6.dp))
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp)),
                color = color,
                trackColor = Color(0xFF334155)
            )
        }
    }
}
