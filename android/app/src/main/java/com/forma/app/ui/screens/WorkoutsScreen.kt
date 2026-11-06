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
import com.forma.app.data.model.WorkoutEntry
import com.forma.app.data.model.WorkoutRoutine
import com.forma.app.data.repository.FormaRepository
import com.forma.app.ui.theme.DarkCard
import com.forma.app.ui.theme.PrimaryGreen
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

@Composable
fun WorkoutsScreen(
    repository: FormaRepository
) {
    val coroutineScope = rememberCoroutineScope()
    val workoutEntries by repository.workoutEntries.collectAsState()
    val workoutRoutines by repository.workoutRoutines.collectAsState()
    val isWorkoutActive by repository.isWorkoutActive.collectAsState()
    val workoutDurationSeconds by repository.workoutDurationSeconds.collectAsState()

    var showAddWorkoutDialog by remember { mutableStateOf(false) }
    var showStartLiveWorkoutDialog by remember { mutableStateOf(false) }
    var isAnalyzingAI by remember { mutableStateOf(false) }
    var aiErrorMessage by remember { mutableStateOf<String?>(null) }

    // Date selector for top calendar
    val calendarDays = remember {
        val cal = Calendar.getInstance()
        val list = mutableListOf<Date>()
        cal.add(Calendar.DAY_OF_YEAR, -3)
        for (i in 0..6) {
            list.add(cal.time)
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        list
    }
    var selectedDateIndex by remember { mutableIntStateOf(3) } // today

    val dayFormat = SimpleDateFormat("EEE", Locale("pt", "BR"))
    val numFormat = SimpleDateFormat("d", Locale("pt", "BR"))

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF030712))
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        Spacer(modifier = Modifier.height(58.dp))

        // CALENDAR AT THE TOP (User rule: "na aba de treino mude o calendario para o topo")
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Treinos & Rotinas",
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            FloatingActionButton(
                onClick = {
                    aiErrorMessage = null
                    showAddWorkoutDialog = true
                },
                containerColor = PrimaryGreen,
                contentColor = Color.Black,
                shape = CircleShape,
                modifier = Modifier.size(44.dp)
            ) {
                Icon(Icons.Default.Add, contentDescription = "Adicionar Treino")
            }
        }

        Spacer(modifier = Modifier.height(14.dp))

        // Week Calendar Strip
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            calendarDays.forEachIndexed { index, date ->
                val isSelected = index == selectedDateIndex
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = if (isSelected) PrimaryGreen else DarkCard,
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(12.dp))
                        .clickable { selectedDateIndex = index }
                ) {
                    Column(
                        modifier = Modifier.padding(vertical = 10.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = dayFormat.format(date).uppercase().replace(".", ""),
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = if (isSelected) Color.Black else Color(0xFF94A3B8)
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = numFormat.format(date),
                            fontSize = 15.sp,
                            fontWeight = FontWeight.ExtraBold,
                            color = if (isSelected) Color.Black else Color.White
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Active Workout Banner / Start Live Workout Card
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(
                containerColor = if (isWorkoutActive) Color(0xFFEF4444).copy(alpha = 0.15f) else DarkCard
            ),
            border = if (isWorkoutActive) androidx.compose.foundation.BorderStroke(1.dp, Color(0xFFEF4444).copy(alpha = 0.5f)) else null,
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    modifier = Modifier.weight(1f),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(if (isWorkoutActive) Color(0xFFEF4444).copy(alpha = 0.2f) else PrimaryGreen.copy(alpha = 0.15f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = if (isWorkoutActive) Icons.Default.DirectionsRun else Icons.Default.Timer,
                            contentDescription = null,
                            tint = if (isWorkoutActive) Color(0xFFEF4444) else PrimaryGreen,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            text = if (isWorkoutActive) "Treino Ativo na Ilha" else "Iniciar Treino com Ilha",
                            fontWeight = FontWeight.Bold,
                            color = Color.White,
                            fontSize = 15.sp
                        )
                        if (isWorkoutActive) {
                            val mins = workoutDurationSeconds / 60
                            val secs = workoutDurationSeconds % 60
                            val burnedEst = (workoutDurationSeconds * 0.12).toInt()
                            Text(
                                text = String.format("%02d:%02d • ~%d kcal queimadas", mins, secs, burnedEst),
                                color = Color(0xFFFCA5A5),
                                fontSize = 13.sp
                            )
                        } else {
                            Text(
                                text = "Acompanhamento no recorte do celular",
                                color = Color(0xFF94A3B8),
                                fontSize = 12.sp
                            )
                        }
                    }
                }

                Button(
                    onClick = {
                        if (isWorkoutActive) {
                            coroutineScope.launch {
                                repository.stopWorkout()
                            }
                        } else {
                            showStartLiveWorkoutDialog = true
                        }
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isWorkoutActive) Color(0xFFEF4444) else PrimaryGreen,
                        contentColor = if (isWorkoutActive) Color.White else Color.Black
                    ),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Text(
                        text = if (isWorkoutActive) "Encerrar" else "Iniciar",
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // History of Workouts & Routines
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Routines Section (especially those generated by AI analysis)
            if (workoutRoutines.isNotEmpty()) {
                item {
                    Text(
                        text = "Rotinas Salvas & Sugeridas",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                        modifier = Modifier.padding(vertical = 4.dp)
                    )
                }

                items(workoutRoutines) { routine ->
                    RoutineCard(
                        routine = routine,
                        onStart = {
                            coroutineScope.launch {
                                repository.startWorkout(routine.title)
                            }
                        }
                    )
                }
            }

            item {
                Text(
                    text = "Treinos Realizados",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    modifier = Modifier.padding(vertical = 4.dp)
                )
            }

            if (workoutEntries.isEmpty()) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(24.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "Nenhum treino registrado ainda",
                            color = Color(0xFF64748B),
                            fontSize = 13.sp
                        )
                    }
                }
            } else {
                items(workoutEntries) { workout ->
                    WorkoutItemCard(
                        workout = workout,
                        onDelete = {
                            coroutineScope.launch {
                                repository.deleteWorkoutEntry(workout.id)
                            }
                        }
                    )
                }
            }

            item {
                Spacer(modifier = Modifier.height(40.dp))
            }
        }
    }

    // Start Live Workout Dialog
    if (showStartLiveWorkoutDialog) {
        var workoutName by remember { mutableStateOf("Treino de Musculação") }

        AlertDialog(
            onDismissRequest = { showStartLiveWorkoutDialog = false },
            title = { Text("Iniciar Treino na Ilha Dinâmica") },
            text = {
                Column {
                    Text(
                        "O cronômetro e a queima calórica estimada ficarão ativos na Ilha Dinâmica no topo da tela do seu Android:",
                        fontSize = 13.sp,
                        color = Color(0xFF94A3B8)
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    OutlinedTextField(
                        value = workoutName,
                        onValueChange = { workoutName = it },
                        label = { Text("Nome do Treino / Atividade") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        showStartLiveWorkoutDialog = false
                        coroutineScope.launch {
                            repository.startWorkout(workoutName.trim().ifEmpty { "Treino" })
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = PrimaryGreen, contentColor = Color.Black)
                ) {
                    Text("Começar Treino")
                }
            },
            dismissButton = {
                TextButton(onClick = { showStartLiveWorkoutDialog = false }) {
                    Text("Cancelar")
                }
            }
        )
    }

    // Add Workout with AI Dialog
    if (showAddWorkoutDialog) {
        var workoutText by remember { mutableStateOf("") }

        AlertDialog(
            onDismissRequest = { if (!isAnalyzingAI) showAddWorkoutDialog = false },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.AutoAwesome, contentDescription = null, tint = PrimaryGreen)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Adicionar Treino com IA")
                }
            },
            text = {
                Column {
                    Text(
                        "Descreva seu treino livremente. A IA calculará o gasto calórico, intensidade e detalhes da atividade:",
                        fontSize = 13.sp,
                        color = Color(0xFF94A3B8)
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    OutlinedTextField(
                        value = workoutText,
                        onValueChange = { workoutText = it },
                        label = { Text("Ex: Treino pesado de costas e bíceps por 55 minutos") },
                        minLines = 3,
                        maxLines = 5,
                        modifier = Modifier.fillMaxWidth()
                    )
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
                        if (workoutText.isBlank()) return@Button
                        isAnalyzingAI = true
                        aiErrorMessage = null
                        coroutineScope.launch {
                            val result = repository.analyzeWorkout(workoutText.trim())
                            isAnalyzingAI = false
                            if (result.isSuccess) {
                                showAddWorkoutDialog = false
                            } else {
                                aiErrorMessage = result.exceptionOrNull()?.message ?: "Erro ao analisar treino."
                            }
                        }
                    },
                    enabled = !isAnalyzingAI,
                    colors = ButtonDefaults.buttonColors(containerColor = PrimaryGreen, contentColor = Color.Black)
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
                    onClick = { showAddWorkoutDialog = false },
                    enabled = !isAnalyzingAI
                ) {
                    Text("Cancelar")
                }
            }
        )
    }
}

@Composable
private fun RoutineCard(
    routine: WorkoutRoutine,
    onStart: () -> Unit
) {
    val isAi = routine.title.contains("GERADA POR IA", ignoreCase = true)

    Card(
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = DarkCard),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    modifier = Modifier.weight(1f),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = routine.title.replace("[GERADA POR IA] ", ""),
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp,
                        color = Color.White
                    )
                    if (isAi) {
                        Spacer(modifier = Modifier.width(8.dp))
                        Surface(
                            shape = RoundedCornerShape(6.dp),
                            color = PrimaryGreen.copy(alpha = 0.2f)
                        ) {
                            Text(
                                text = "GERADA POR IA",
                                color = PrimaryGreen,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                            )
                        }
                    }
                }

                Button(
                    onClick = onStart,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = PrimaryGreen.copy(alpha = 0.2f),
                        contentColor = PrimaryGreen
                    ),
                    shape = RoundedCornerShape(8.dp),
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp)
                ) {
                    Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(14.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Iniciar", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                }
            }

            if (routine.notes.isNotBlank()) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = routine.notes,
                    color = Color(0xFF94A3B8),
                    fontSize = 12.sp
                )
            }

            if (routine.exercises.isNotEmpty()) {
                Spacer(modifier = Modifier.height(8.dp))
                routine.exercises.take(3).forEach { ex ->
                    Text(
                        text = "• ${ex.name} (${ex.sets} séries x ${ex.reps} reps)",
                        fontSize = 12.sp,
                        color = Color(0xFFCBD5E1)
                    )
                }
                if (routine.exercises.size > 3) {
                    Text(
                        text = "+ mais ${routine.exercises.size - 3} exercícios",
                        fontSize = 11.sp,
                        color = Color(0xFF64748B)
                    )
                }
            }
        }
    }
}

@Composable
private fun WorkoutItemCard(
    workout: WorkoutEntry,
    onDelete: () -> Unit
) {
    Card(
        shape = RoundedCornerShape(14.dp),
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
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = workout.title,
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp,
                    color = Color.White
                )
                Spacer(modifier = Modifier.height(4.dp))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "${workout.caloriesBurned.toInt()} kcal",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFFF97316)
                    )
                    Text("•", color = Color(0xFF64748B))
                    Text("${workout.durationMinutes} min", fontSize = 12.sp, color = Color(0xFF94A3B8))
                    Text("•", color = Color(0xFF64748B))
                    Text(workout.workoutType, fontSize = 12.sp, color = PrimaryGreen)
                }
            }

            IconButton(onClick = onDelete) {
                Icon(
                    imageVector = Icons.Default.DeleteOutline,
                    contentDescription = "Excluir",
                    tint = Color(0xFF64748B)
                )
            }
        }
    }
}
