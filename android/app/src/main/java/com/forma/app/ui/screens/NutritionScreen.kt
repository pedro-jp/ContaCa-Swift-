package com.forma.app.ui.screens

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
import com.forma.app.data.model.FoodEntry
import com.forma.app.data.model.MealType
import com.forma.app.data.repository.FormaRepository
import com.forma.app.ui.theme.DarkCard
import com.forma.app.ui.theme.PrimaryGreen
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

@Composable
fun NutritionScreen(
    repository: FormaRepository
) {
    val coroutineScope = rememberCoroutineScope()
    val userProfile by repository.userProfile.collectAsState()
    val dailySummary by repository.dailySummary.collectAsState()
    val foodEntries by repository.foodEntries.collectAsState()

    var showAddMealDialog by remember { mutableStateOf(false) }
    var selectedMealTypeForDialog by remember { mutableStateOf(MealType.LUNCH) }
    var isAnalyzingAI by remember { mutableStateOf(false) }
    var aiErrorMessage by remember { mutableStateOf<String?>(null) }

    // Week selector (Segunda a Domingo como no iOS)
    val calendarDays = remember {
        val cal = Calendar.getInstance()
        cal.firstDayOfWeek = Calendar.MONDAY
        cal.set(Calendar.DAY_OF_WEEK, Calendar.MONDAY)
        val list = mutableListOf<Date>()
        for (i in 0..6) {
            list.add(cal.time)
            cal.add(Calendar.DAY_OF_WEEK, 1)
        }
        list
    }
    val currentDayIndex = remember {
        val cal = Calendar.getInstance()
        val dayOfWeek = cal.get(Calendar.DAY_OF_WEEK)
        // Calendar.MONDAY = 2, SUNDAY = 1
        if (dayOfWeek == Calendar.SUNDAY) 6 else dayOfWeek - 2
    }
    var selectedDateIndex by remember { mutableIntStateOf(currentDayIndex) }

    val dayFormat = SimpleDateFormat("EEE", Locale("pt", "BR"))
    val numFormat = SimpleDateFormat("d", Locale("pt", "BR"))

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF030712))
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        Spacer(modifier = Modifier.height(58.dp))

        // Header estilo iOS
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "Diário Alimentar",
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    text = "Controle diário de nutrientes",
                    fontSize = 13.sp,
                    color = Color(0xFF94A3B8)
                )
            }

            Button(
                onClick = {
                    selectedMealTypeForDialog = getSuggestedMealByTime()
                    aiErrorMessage = null
                    showAddMealDialog = true
                },
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color(0xFF54E1C3),
                    contentColor = Color.Black
                ),
                shape = RoundedCornerShape(20.dp),
                contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp)
            ) {
                Icon(Icons.Default.AutoAwesome, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(6.dp))
                Text("Refeição", fontWeight = FontWeight.Bold, fontSize = 13.sp)
            }
        }

        Spacer(modifier = Modifier.height(14.dp))

        // Week Calendar Strip (Segunda a Domingo)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            calendarDays.forEachIndexed { index, date ->
                val isSelected = index == selectedDateIndex
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = if (isSelected) Color(0xFF54E1C3) else DarkCard,
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(12.dp))
                        .clickable { selectedDateIndex = index }
                ) {
                    Column(
                        modifier = Modifier.padding(vertical = 8.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = dayFormat.format(date).uppercase().replace(".", "").take(3),
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = if (isSelected) Color.Black else Color(0xFF94A3B8)
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = numFormat.format(date),
                            fontSize = 14.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = if (isSelected) Color.Black else Color.White
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(14.dp))

        // Card de Água com Botão +250ml
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = DarkCard),
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(14.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(38.dp)
                            .clip(CircleShape)
                            .background(Color(0xFF0284C7).copy(alpha = 0.2f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.WaterDrop,
                            contentDescription = null,
                            tint = Color(0xFF38BDF8),
                            modifier = Modifier.size(20.dp)
                        )
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            text = "Meta de Água",
                            fontWeight = FontWeight.Bold,
                            color = Color.White,
                            fontSize = 14.sp
                        )
                        val target = userProfile.targetWaterMilliliters
                        val pct = if (target > 0) {
                            (dailySummary.totalWaterMl * 100) / target
                        } else 0
                        Text(
                            text = "${dailySummary.totalWaterMl} ml / $target ml ($pct%)",
                            color = Color(0xFF94A3B8),
                            fontSize = 12.sp
                        )
                    }
                }

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
                    shape = RoundedCornerShape(8.dp),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                ) {
                    Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("+250ml", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                }
            }
        }

        Spacer(modifier = Modifier.height(14.dp))

        // Seções por Refeição (Café da Manhã, Almoço, Jantar, Lanches)
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            MealType.values().forEach { mealType ->
                val entries = foodEntries.filter { it.mealType == mealType }
                item {
                    MealSectionView(
                        mealType = mealType,
                        entries = entries,
                        onAddClick = {
                            selectedMealTypeForDialog = mealType
                            aiErrorMessage = null
                            showAddMealDialog = true
                        },
                        onDeleteEntry = { entry ->
                            coroutineScope.launch {
                                repository.deleteFoodEntry(entry.id)
                            }
                        }
                    )
                }
            }

            item {
                Spacer(modifier = Modifier.height(30.dp))
            }
        }
    }

    // Add Meal with AI Dialog
    if (showAddMealDialog) {
        var mealDescription by remember { mutableStateOf("") }
        var isSnack by remember { mutableStateOf(selectedMealTypeForDialog == MealType.SNACKS) }
        var currentMealType by remember { mutableStateOf(selectedMealTypeForDialog) }

        AlertDialog(
            onDismissRequest = { if (!isAnalyzingAI) showAddMealDialog = false },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.AutoAwesome, contentDescription = null, tint = Color(0xFF54E1C3))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Adicionar Refeição")
                }
            },
            text = {
                Column {
                    Text(
                        "Descreva os alimentos livremente. A IA calculará as calorias e macronutrientes automaticamente:",
                        fontSize = 13.sp,
                        color = Color(0xFF94A3B8)
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    OutlinedTextField(
                        value = mealDescription,
                        onValueChange = { mealDescription = it },
                        label = { Text("Ex: 150g de frango grelhado, arroz e salada") },
                        minLines = 3,
                        maxLines = 5,
                        modifier = Modifier.fillMaxWidth()
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    // Seletor do Tipo de Refeição
                    Text("Tipo da Refeição:", fontSize = 12.sp, color = Color(0xFF94A3B8), fontWeight = FontWeight.Medium)
                    Spacer(modifier = Modifier.height(6.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        MealType.values().forEach { mt ->
                            val isSel = currentMealType == mt
                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = if (isSel) Color(0xFF54E1C3) else Color(0xFF1E293B),
                                modifier = Modifier
                                    .weight(1f)
                                    .clickable {
                                        currentMealType = mt
                                        isSnack = mt == MealType.SNACKS
                                    }
                            ) {
                                Text(
                                    text = mt.title.replace(" da Manhã", ""),
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (isSel) Color.Black else Color.White,
                                    modifier = Modifier.padding(vertical = 6.dp),
                                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                                )
                            }
                        }
                    }

                    if (aiErrorMessage != null) {
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = aiErrorMessage ?: "",
                            color = Color(0xFFEF4444),
                            fontSize = 12.sp
                        )
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        if (mealDescription.isBlank()) return@Button
                        isAnalyzingAI = true
                        aiErrorMessage = null
                        coroutineScope.launch {
                            val result = repository.analyzeMeal(
                                text = mealDescription.trim(),
                                mealType = currentMealType.title,
                                isSnack = isSnack
                            )
                            isAnalyzingAI = false
                            if (result.isSuccess) {
                                showAddMealDialog = false
                            } else {
                                aiErrorMessage = result.exceptionOrNull()?.message ?: "Erro ao analisar com IA."
                            }
                        }
                    },
                    enabled = !isAnalyzingAI,
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF54E1C3), contentColor = Color.Black)
                ) {
                    if (isAnalyzingAI) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(18.dp),
                            color = Color.Black,
                            strokeWidth = 2.dp
                        )
                    } else {
                        Text("Analisar com IA")
                    }
                }
            },
            dismissButton = {
                TextButton(
                    onClick = { showAddMealDialog = false },
                    enabled = !isAnalyzingAI
                ) {
                    Text("Cancelar")
                }
            }
        )
    }
}

@Composable
private fun MealSectionView(
    mealType: MealType,
    entries: List<FoodEntry>,
    onAddClick: () -> Unit,
    onDeleteEntry: (FoodEntry) -> Unit
) {
    val totalKcal = entries.sumOf { it.calories }.toInt()

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = DarkCard),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(mealType.icon, fontSize = 18.sp)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = mealType.title,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                        color = Color.White
                    )
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (totalKcal > 0) {
                        Text(
                            text = "$totalKcal kcal",
                            color = Color(0xFF54E1C3),
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.sp
                        )
                        Spacer(modifier = Modifier.width(10.dp))
                    }

                    IconButton(
                        onClick = onAddClick,
                        modifier = Modifier.size(28.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.AddCircle,
                            contentDescription = "Adicionar",
                            tint = Color(0xFF54E1C3)
                        )
                    }
                }
            }

            if (entries.isEmpty()) {
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "Nenhum alimento registrado",
                    color = Color(0xFF64748B),
                    fontSize = 12.sp
                )
            } else {
                Spacer(modifier = Modifier.height(10.dp))
                entries.forEach { food ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(food.name, color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Medium)
                            Text(
                                text = "${food.calories.toInt()} kcal • P: ${food.protein.toInt()}g • C: ${food.carbohydrates.toInt()}g • G: ${food.fat.toInt()}g",
                                color = Color(0xFF94A3B8),
                                fontSize = 11.sp
                            )
                        }

                        IconButton(
                            onClick = { onDeleteEntry(food) },
                            modifier = Modifier.size(24.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.DeleteOutline,
                                contentDescription = "Excluir",
                                tint = Color(0xFF64748B),
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}

private fun getSuggestedMealByTime(): MealType {
    val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
    return when (hour) {
        in 5..10 -> MealType.BREAKFAST
        in 11..14 -> MealType.LUNCH
        in 15..18 -> MealType.SNACKS
        in 19..22 -> MealType.DINNER
        else -> MealType.SNACKS
    }
}
