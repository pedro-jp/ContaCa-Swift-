package com.contaca.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.contaca.app.data.model.EvolutionAIAnalysis
import com.contaca.app.data.model.WeightEntry
import com.contaca.app.data.repository.ContaCaRepository
import com.contaca.app.ui.theme.DarkCard
import com.contaca.app.ui.theme.PrimaryGreen
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

enum class EvolutionTab(val title: String) {
    OVERVIEW("Visão Geral"),
    AI_ANALYSIS("Análise com IA")
}

@Composable
fun EvolutionScreen(
    repository: ContaCaRepository
) {
    val coroutineScope = rememberCoroutineScope()
    val userProfile by repository.userProfile.collectAsState()
    val weightEntries by repository.weightEntries.collectAsState()
    val aiAnalyses by repository.aiAnalyses.collectAsState()

    var selectedTab by remember { mutableStateOf(EvolutionTab.OVERVIEW) }

    var showWeightDialog by remember { mutableStateOf(false) }
    var isAnalyzingAI by remember { mutableStateOf(false) }
    var aiErrorMessage by remember { mutableStateOf<String?>(null) }
    var latestAnalysis by remember { mutableStateOf<EvolutionAIAnalysis?>(aiAnalyses.firstOrNull()) }

    LaunchedEffect(aiAnalyses) {
        if (latestAnalysis == null && aiAnalyses.isNotEmpty()) {
            latestAnalysis = aiAnalyses.first()
        }
    }

    val dateFormat = SimpleDateFormat("dd/MM/yyyy", Locale("pt", "BR"))

    // IMC & TMB
    val heightM = if (userProfile.heightMeters > 0.5) userProfile.heightMeters else 1.78
    val weightKg = userProfile.currentWeight
    val imc = weightKg / (heightM * heightM)
    val tmb = userProfile.tmb.toInt()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF030712))
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        Spacer(modifier = Modifier.height(58.dp))

        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "Evolução Corporal",
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    text = "Balanço calórico, peso e recomendações",
                    fontSize = 13.sp,
                    color = Color(0xFF94A3B8)
                )
            }

            IconButton(
                onClick = { showWeightDialog = true }
            ) {
                Icon(
                    imageVector = Icons.Default.Scale,
                    contentDescription = "Registrar Peso",
                    tint = Color(0xFF54E1C3),
                    modifier = Modifier.size(28.dp)
                )
            }
        }

        Spacer(modifier = Modifier.height(14.dp))

        // Segmented Control (Visão Geral / Análise com IA) - como no iOS
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
                EvolutionTab.values().forEach { tab ->
                    val isSel = selectedTab == tab
                    Surface(
                        shape = RoundedCornerShape(8.dp),
                        color = if (isSel) Color(0xFF1E293B) else Color.Transparent,
                        modifier = Modifier
                            .weight(1f)
                            .clickable { selectedTab = tab }
                    ) {
                        Text(
                            text = tab.title,
                            color = if (isSel) Color.White else Color(0xFF94A3B8),
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
        }

        Spacer(modifier = Modifier.height(16.dp))

        if (selectedTab == EvolutionTab.OVERVIEW) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Card de Métricas Corporais (IMC, TMB, Peso Atual vs Meta)
                item {
                    Card(
                        shape = RoundedCornerShape(18.dp),
                        colors = CardDefaults.cardColors(containerColor = DarkCard),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                            horizontalArrangement = Arrangement.SpaceAround
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("Peso Atual", fontSize = 11.sp, color = Color(0xFF94A3B8))
                                Text("${weightKg} kg", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color.White)
                                Text("meta ${userProfile.targetWeight} kg", fontSize = 10.sp, color = Color(0xFF54E1C3))
                            }
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("IMC", fontSize = 11.sp, color = Color(0xFF94A3B8))
                                Text(String.format(Locale.US, "%.1f", imc), fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color.White)
                                Text("Normal", fontSize = 10.sp, color = Color(0xFFD4F782))
                            }
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                val tdee = userProfile.contextualTdee(context = repository.buildRecalculationContext()).toInt()
                                Text("Taxa Basal (TMB)", fontSize = 11.sp, color = Color(0xFF94A3B8))
                                Text("$tmb kcal", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color(0xFF38BDF8))
                                Text("total ~$tdee kcal", fontSize = 10.sp, color = Color(0xFF64748B))
                            }
                        }
                    }
                }

                // Weekly Calorie Balance Card (consumidas vs gastas)
                item {
                    Card(
                        shape = RoundedCornerShape(18.dp),
                        colors = CardDefaults.cardColors(containerColor = DarkCard),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "Balanço Calórico Semanal",
                                    fontWeight = FontWeight.Bold,
                                    color = Color.White,
                                    fontSize = 15.sp
                                )
                                Icon(
                                    imageVector = Icons.Default.Timeline,
                                    contentDescription = null,
                                    tint = Color(0xFF54E1C3)
                                )
                            }

                            Spacer(modifier = Modifier.height(14.dp))

                            val days = listOf("Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom")
                            val consumedValues = listOf(1950, 2100, 1800, 2250, 2000, 2400, 1900)
                            val burnedValues = listOf(450, 600, 350, 500, 700, 300, 550)

                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(120.dp),
                                horizontalArrangement = Arrangement.SpaceEvenly,
                                verticalAlignment = Alignment.Bottom
                            ) {
                                days.forEachIndexed { idx, day ->
                                    val consumed = consumedValues[idx]
                                    val burned = burnedValues[idx]
                                    val maxVal = 2600f

                                    val cHeight = (consumed / maxVal * 75).dp
                                    val bHeight = (burned / maxVal * 75).dp

                                    Column(
                                        horizontalAlignment = Alignment.CenterHorizontally,
                                        verticalArrangement = Arrangement.Bottom,
                                        modifier = Modifier.fillMaxHeight()
                                    ) {
                                        Row(
                                            horizontalArrangement = Arrangement.spacedBy(3.dp),
                                            verticalAlignment = Alignment.Bottom
                                        ) {
                                            Box(
                                                modifier = Modifier
                                                    .width(10.dp)
                                                    .height(cHeight)
                                                    .clip(RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp))
                                                    .background(Color(0xFF54E1C3))
                                            )
                                            Box(
                                                modifier = Modifier
                                                    .width(10.dp)
                                                    .height(bHeight)
                                                    .clip(RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp))
                                                    .background(Color(0xFFF97316))
                                            )
                                        }
                                        Spacer(modifier = Modifier.height(6.dp))
                                        Text(
                                            text = day,
                                            fontSize = 11.sp,
                                            color = Color(0xFF94A3B8)
                                        )
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.Center
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Box(
                                        modifier = Modifier
                                            .size(8.dp)
                                            .clip(CircleShape)
                                            .background(Color(0xFF54E1C3))
                                    )
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("Consumidas", fontSize = 11.sp, color = Color(0xFF94A3B8))
                                }
                                Spacer(modifier = Modifier.width(20.dp))
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Box(
                                        modifier = Modifier
                                            .size(8.dp)
                                            .clip(CircleShape)
                                            .background(Color(0xFFF97316))
                                    )
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("Gastas (Treinos)", fontSize = 11.sp, color = Color(0xFF94A3B8))
                                }
                            }
                        }
                    }
                }

                // Weight History Section
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Histórico de Peso",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                        Text(
                            text = "Atual: ${userProfile.currentWeight} kg",
                            fontSize = 13.sp,
                            color = Color(0xFF54E1C3),
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }

                if (weightEntries.isEmpty()) {
                    item {
                        Text(
                            text = "Nenhum registro de peso ainda. Toque no ícone da balança para registrar.",
                            fontSize = 12.sp,
                            color = Color(0xFF64748B)
                        )
                    }
                } else {
                    items(weightEntries) { weight ->
                        Card(
                            shape = RoundedCornerShape(12.dp),
                            colors = CardDefaults.cardColors(containerColor = DarkCard),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(12.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(
                                        imageVector = Icons.Default.Scale,
                                        contentDescription = null,
                                        tint = Color(0xFF54E1C3),
                                        modifier = Modifier.size(20.dp)
                                    )
                                    Spacer(modifier = Modifier.width(10.dp))
                                    Text(
                                        text = "${weight.weight} kg",
                                        fontWeight = FontWeight.Bold,
                                        color = Color.White,
                                        fontSize = 15.sp
                                    )
                                }
                                Text(
                                    text = dateFormat.format(Date(weight.entryDate)),
                                    color = Color(0xFF94A3B8),
                                    fontSize = 12.sp
                                )
                            }
                        }
                    }
                }

                item {
                    Spacer(modifier = Modifier.height(40.dp))
                }
            }
        } else {
            // ABA ANÁLISE COM IA (como no iOS)
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                item {
                    Card(
                        shape = RoundedCornerShape(18.dp),
                        colors = CardDefaults.cardColors(containerColor = Color(0xFF1E293B)),
                        border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF54E1C3).copy(alpha = 0.3f)),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(18.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(
                                    modifier = Modifier
                                        .size(36.dp)
                                        .clip(CircleShape)
                                        .background(Color(0xFF54E1C3).copy(alpha = 0.2f)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.AutoAwesome,
                                        contentDescription = null,
                                        tint = Color(0xFF54E1C3),
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                                Spacer(modifier = Modifier.width(12.dp))
                                Column {
                                    Text(
                                        text = "Diagnóstico Completo com IA",
                                        fontWeight = FontWeight.Bold,
                                        color = Color.White,
                                        fontSize = 15.sp
                                    )
                                    Text(
                                        text = "Analisa seu histórico de logs e ajusta seus treinos e metas",
                                        fontSize = 12.sp,
                                        color = Color(0xFF94A3B8)
                                    )
                                }
                            }

                            if (aiErrorMessage != null) {
                                Spacer(modifier = Modifier.height(10.dp))
                                Text(
                                    text = aiErrorMessage ?: "",
                                    color = Color(0xFFEF4444),
                                    fontSize = 12.sp
                                )
                            }

                            Spacer(modifier = Modifier.height(14.dp))

                            Button(
                                onClick = {
                                    isAnalyzingAI = true
                                    aiErrorMessage = null
                                    coroutineScope.launch {
                                        val result = repository.analyzeEvolution()
                                        isAnalyzingAI = false
                                        if (result.isSuccess) {
                                            latestAnalysis = result.getOrNull()
                                        } else {
                                            aiErrorMessage = result.exceptionOrNull()?.message ?: "Erro ao gerar análise."
                                        }
                                    }
                                },
                                enabled = !isAnalyzingAI,
                                modifier = Modifier.fillMaxWidth(),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = Color(0xFF54E1C3),
                                    contentColor = Color.Black
                                ),
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                if (isAnalyzingAI) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(20.dp),
                                        color = Color.Black,
                                        strokeWidth = 2.dp
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text("Analisando seus dados...", fontWeight = FontWeight.Bold)
                                } else {
                                    Icon(Icons.Default.Psychology, contentDescription = null, modifier = Modifier.size(18.dp))
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text("Executar Análise com IA", fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                    }
                }

                // Latest AI Analysis Display
                latestAnalysis?.let { analysis ->
                    item {
                        Card(
                            shape = RoundedCornerShape(18.dp),
                            colors = CardDefaults.cardColors(containerColor = DarkCard),
                            border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF334155)),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(modifier = Modifier.padding(18.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = "Diagnóstico da IA",
                                        fontWeight = FontWeight.Bold,
                                        color = Color(0xFF54E1C3),
                                        fontSize = 16.sp
                                    )
                                    Text(
                                        text = dateFormat.format(Date(analysis.generatedAt)),
                                        fontSize = 12.sp,
                                        color = Color(0xFF64748B)
                                    )
                                }

                                Spacer(modifier = Modifier.height(12.dp))

                                Text(
                                    text = "${analysis.statusSummary}\n\n${analysis.calorieDiagnostic}",
                                    color = Color(0xFFCBD5E1),
                                    fontSize = 13.sp,
                                    lineHeight = 18.sp
                                )

                                // Suggested Targets
                                analysis.suggestedTargets?.let { targets ->
                                    Spacer(modifier = Modifier.height(14.dp))
                                    Text(
                                        text = "Metas Sugeridas:",
                                        fontWeight = FontWeight.Bold,
                                        color = Color.White,
                                        fontSize = 13.sp
                                    )
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                                    ) {
                                        Surface(
                                            shape = RoundedCornerShape(8.dp),
                                            color = Color(0xFF1E293B),
                                            modifier = Modifier.weight(1f)
                                        ) {
                                            Column(modifier = Modifier.padding(8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                                Text("Calorias", fontSize = 10.sp, color = Color(0xFF94A3B8))
                                                Text("${targets.dailyCalories.toInt()} kcal", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Color(0xFF54E1C3))
                                            }
                                        }
                                        Surface(
                                            shape = RoundedCornerShape(8.dp),
                                            color = Color(0xFF1E293B),
                                            modifier = Modifier.weight(1f)
                                        ) {
                                            Column(modifier = Modifier.padding(8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                                Text("Água", fontSize = 10.sp, color = Color(0xFF94A3B8))
                                                Text("${targets.waterMilliliters} ml", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Color(0xFF38BDF8))
                                            }
                                        }
                                        Surface(
                                            shape = RoundedCornerShape(8.dp),
                                            color = Color(0xFF1E293B),
                                            modifier = Modifier.weight(1f)
                                        ) {
                                            Column(modifier = Modifier.padding(8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                                Text("Proteína", fontSize = 10.sp, color = Color(0xFF94A3B8))
                                                Text("${targets.proteinGrams.toInt()}g", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Color(0xFFD4F782))
                                            }
                                        }
                                    }
                                    Spacer(modifier = Modifier.height(10.dp))
                                    OutlinedButton(
                                        onClick = {
                                            val updated = userProfile.copy(
                                                targetCalorieIntake = targets.dailyCalories,
                                                targetProtein = targets.proteinGrams,
                                                targetCarbohydrates = targets.carbsGrams,
                                                targetFat = targets.fatGrams,
                                                targetWaterMilliliters = targets.waterMilliliters
                                            )
                                            coroutineScope.launch {
                                                repository.updateProfile(updated)
                                                repository.syncPush()
                                            }
                                        },
                                        modifier = Modifier.fillMaxWidth(),
                                        shape = RoundedCornerShape(10.dp),
                                        border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF54E1C3))
                                    ) {
                                        Text("Aplicar Metas ao Perfil", color = Color(0xFF54E1C3), fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                    }
                                }

                                // Recommended Routine
                                analysis.recommendedRoutine?.let { routine ->
                                    Spacer(modifier = Modifier.height(14.dp))
                                    Text(
                                        text = "Ficha Recomendada (Salva em Treinos com a tag GERADA POR IA):",
                                        fontWeight = FontWeight.Bold,
                                        color = Color.White,
                                        fontSize = 12.sp
                                    )
                                    Spacer(modifier = Modifier.height(6.dp))
                                    Surface(
                                        shape = RoundedCornerShape(10.dp),
                                        color = Color(0xFF0F172A),
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Column(modifier = Modifier.padding(10.dp)) {
                                            Text(
                                                text = routine.title,
                                                fontWeight = FontWeight.Bold,
                                                color = Color(0xFF54E1C3),
                                                fontSize = 13.sp
                                            )
                                            Text(
                                                text = "${routine.workoutType} • Foco: ${routine.hypertrophyFocus}",
                                                color = Color(0xFF94A3B8),
                                                fontSize = 11.sp
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                item {
                    Spacer(modifier = Modifier.height(40.dp))
                }
            }
        }
    }

    // Weight Dialog
    if (showWeightDialog) {
        var weightInput by remember { mutableStateOf(userProfile.currentWeight.toString()) }

        AlertDialog(
            onDismissRequest = { showWeightDialog = false },
            title = { Text("Registrar Peso Atual") },
            text = {
                Column {
                    Text("Informe seu peso em kg:", fontSize = 13.sp, color = Color(0xFF94A3B8))
                    Spacer(modifier = Modifier.height(10.dp))
                    OutlinedTextField(
                        value = weightInput,
                        onValueChange = { weightInput = it },
                        label = { Text("Peso (kg)") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val parsed = weightInput.replace(",", ".").toDoubleOrNull() ?: userProfile.currentWeight
                        coroutineScope.launch {
                            repository.addWeight(parsed)
                        }
                        showWeightDialog = false
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF54E1C3), contentColor = Color.Black)
                ) {
                    Text("Salvar")
                }
            },
            dismissButton = {
                TextButton(onClick = { showWeightDialog = false }) {
                    Text("Cancelar")
                }
            }
        )
    }
}
