package com.forma.app.ui.screens

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.forma.app.R
import com.forma.app.data.model.FitnessGoal
import com.forma.app.data.model.UserProfile
import com.forma.app.data.repository.FormaRepository
import com.forma.app.ui.island.DeviceCutoutDetector
import com.forma.app.ui.island.DynamicIslandOverlayService
import com.forma.app.ui.island.DynamicIslandState
import com.forma.app.ui.island.IslandPreset
import com.forma.app.ui.theme.DarkCard
import com.forma.app.ui.theme.PrimaryGreen
import kotlinx.coroutines.launch

@Composable
fun ProfileAndIslandScreen(
    repository: FormaRepository,
    islandState: DynamicIslandState,
    onLogout: () -> Unit
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val userProfile by repository.userProfile.collectAsState()
    val authUser by repository.authUser.collectAsState()

    var showEditProfileDialog by remember { mutableStateOf(false) }
    var isSyncing by remember { mutableStateOf(false) }
    var syncStatusMessage by remember { mutableStateOf<String?>(null) }

    // Dynamic Island State
    val isIslandEnabled by islandState.isEnabled.collectAsState()
    val currentPreset by islandState.preset.collectAsState()
    val customX by islandState.customXOffset.collectAsState()
    val customY by islandState.customYOffset.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF030712))
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        Spacer(modifier = Modifier.height(58.dp))

        // Header
        Text(
            text = "Perfil & Ilha Dinâmica",
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
        Text(
            text = "Personalize suas metas e adapte a ilha ao seu celular",
            fontSize = 13.sp,
            color = Color(0xFF94A3B8)
        )

        Spacer(modifier = Modifier.height(16.dp))

        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // User Card com foto e dados (Estilo iOS)
            item {
                Card(
                    shape = RoundedCornerShape(18.dp),
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
                                Image(
                                    painter = painterResource(id = R.drawable.profile),
                                    contentDescription = "Foto",
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier
                                        .size(54.dp)
                                        .clip(CircleShape)
                                        .border(1.5.dp, Color.White.copy(alpha = 0.1f), CircleShape)
                                )
                                Spacer(modifier = Modifier.width(14.dp))
                                Column {
                                    Text(
                                        text = userProfile.name.ifEmpty { "João Pedro" },
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 18.sp,
                                        color = Color.White
                                    )
                                    Text(
                                        text = authUser?.email ?: userProfile.email,
                                        fontSize = 12.sp,
                                        color = Color(0xFF94A3B8)
                                    )
                                }
                            }

                            IconButton(onClick = { showEditProfileDialog = true }) {
                                Icon(Icons.Default.Edit, contentDescription = "Editar", tint = Color(0xFF54E1C3))
                            }
                        }

                        Spacer(modifier = Modifier.height(14.dp))
                        HorizontalDivider(color = Color.White.copy(alpha = 0.08f))
                        Spacer(modifier = Modifier.height(14.dp))

                        // Stats Grid (Peso editável, Altura, Meta Kcal, Meta Água)
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.clickable { showEditProfileDialog = true }) {
                                Text("Peso Atual ✎", fontSize = 11.sp, color = Color(0xFF54E1C3))
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        text = "−",
                                        fontWeight = FontWeight.ExtraBold,
                                        fontSize = 16.sp,
                                        color = Color(0xFF54E1C3),
                                        modifier = Modifier
                                            .clickable {
                                                repository.addWeight((userProfile.currentWeight - 0.5).coerceAtLeast(30.0), "Ajuste rápido")
                                            }
                                            .padding(end = 6.dp)
                                    )
                                    Text("${userProfile.currentWeight} kg", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = Color.White)
                                    Text(
                                        text = "+",
                                        fontWeight = FontWeight.ExtraBold,
                                        fontSize = 16.sp,
                                        color = Color(0xFF54E1C3),
                                        modifier = Modifier
                                            .clickable {
                                                repository.addWeight((userProfile.currentWeight + 0.5).coerceAtMost(300.0), "Ajuste rápido")
                                            }
                                            .padding(start = 6.dp)
                                    )
                                }
                            }
                            Column(modifier = Modifier.clickable { showEditProfileDialog = true }) {
                                Text("Altura", fontSize = 11.sp, color = Color(0xFF94A3B8))
                                Text("${userProfile.heightMeters} m", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = Color.White)
                            }
                            Column {
                                Text("Meta Kcal", fontSize = 11.sp, color = Color(0xFF94A3B8))
                                Text("${userProfile.targetCalorieIntake.toInt()}", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = Color(0xFF54E1C3))
                            }
                            Column {
                                Text("Meta Água", fontSize = 11.sp, color = Color(0xFF94A3B8))
                                Text("${userProfile.targetWaterMilliliters} ml", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = Color(0xFF38BDF8))
                            }
                        }

                        Spacer(modifier = Modifier.height(10.dp))
                        val contextualTdee = userProfile.contextualTdee(context = repository.buildRecalculationContext()).toInt()
                        Text(
                            text = "⚡ TMB: ${userProfile.tmb.toInt()} kcal • Gasto Contextual: $contextualTdee kcal • P ${userProfile.targetProtein.toInt()}g • C ${userProfile.targetCarbohydrates.toInt()}g • G ${userProfile.targetFat.toInt()}g",
                            fontSize = 11.sp,
                            color = Color(0xFF94A3B8)
                        )
                    }
                }
            }

            // SEÇÃO: OBJETIVO CORPORAL (como no iOS)
            item {
                Card(
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.cardColors(containerColor = DarkCard),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(18.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.GpsFixed, contentDescription = null, tint = Color(0xFF54E1C3), modifier = Modifier.size(20.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Objetivo Corporal", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 15.sp)
                        }

                        Spacer(modifier = Modifier.height(12.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            FitnessGoal.values().forEach { goal ->
                                val isSelected = userProfile.goal == goal
                                Surface(
                                    shape = RoundedCornerShape(10.dp),
                                    color = if (isSelected) Color(0xFF183C36) else Color(0xFF0F172A),
                                    border = if (isSelected) androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF54E1C3)) else null,
                                    modifier = Modifier
                                        .weight(1f)
                                        .clickable {
                                            coroutineScope.launch {
                                                repository.updateProfile(repository.previewRecalculatedProfile(newGoal = goal))
                                                repository.syncPush()
                                            }
                                        }
                                ) {
                                    Column(
                                        modifier = Modifier.padding(vertical = 10.dp, horizontal = 4.dp),
                                        horizontalAlignment = Alignment.CenterHorizontally
                                    ) {
                                        Text(
                                            text = goal.title,
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 12.sp,
                                            color = if (isSelected) Color(0xFF54E1C3) else Color.White
                                        )
                                    }
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = userProfile.goal.subtitle,
                            fontSize = 11.sp,
                            color = Color(0xFF94A3B8)
                        )
                    }
                }
            }

            // Sync with Supabase Card
            item {
                Card(
                    shape = RoundedCornerShape(18.dp),
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
                                        .size(38.dp)
                                        .clip(CircleShape)
                                        .background(Color(0xFF3B82F6).copy(alpha = 0.2f)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.CloudSync,
                                        contentDescription = null,
                                        tint = Color(0xFF38BDF8),
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                                Spacer(modifier = Modifier.width(12.dp))
                                Column {
                                    Text(
                                        text = "Nuvem & Supabase",
                                        fontWeight = FontWeight.Bold,
                                        color = Color.White,
                                        fontSize = 15.sp
                                    )
                                    Text(
                                        text = "Sincroniza alimentação, treinos, rotinas e IA",
                                        fontSize = 12.sp,
                                        color = Color(0xFF94A3B8)
                                    )
                                }
                            }
                        }

                        if (syncStatusMessage != null) {
                            Spacer(modifier = Modifier.height(10.dp))
                            Text(
                                text = syncStatusMessage ?: "",
                                color = if (syncStatusMessage?.contains("sucesso", ignoreCase = true) == true) Color(0xFF54E1C3) else Color(0xFFF97316),
                                fontSize = 12.sp
                            )
                        }

                        Spacer(modifier = Modifier.height(12.dp))

                        Button(
                            onClick = {
                                isSyncing = true
                                syncStatusMessage = "Sincronizando com o Supabase..."
                                coroutineScope.launch {
                                    val pushRes = repository.syncPush()
                                    val pullRes = repository.syncPull()
                                    isSyncing = false
                                    if (pushRes.isSuccess && pullRes.isSuccess) {
                                        syncStatusMessage = "Sincronizado com sucesso com o Supabase!"
                                    } else {
                                        syncStatusMessage = "Aviso: Sincronizado localmente no dispositivo."
                                    }
                                }
                            },
                            enabled = !isSyncing,
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color(0xFF1E293B),
                                contentColor = Color.White
                            ),
                            shape = RoundedCornerShape(10.dp)
                        ) {
                            if (isSyncing) {
                                CircularProgressIndicator(modifier = Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("Sincronizando dados...")
                            } else {
                                Icon(Icons.Default.Sync, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Sincronizar Tudo com o Banco de Dados")
                            }
                        }
                    }
                }
            }

            // DYNAMIC ISLAND SECTION (Consistente e funcional fora do app)
            item {
                Text(
                    text = "Ilha Dinâmica (Dynamic Island)",
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF54E1C3),
                    modifier = Modifier.padding(vertical = 4.dp)
                )
            }

            item {
                Card(
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.cardColors(containerColor = DarkCard),
                    border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF54E1C3).copy(alpha = 0.3f)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(18.dp)) {
                        // Switch Liga/Desliga
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text("Ativar Ilha Dinâmica", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 15.sp)
                                Text("Exibe timer de treinos e água no notch até mesmo fora do app", color = Color(0xFF94A3B8), fontSize = 12.sp)
                            }
                            Switch(
                                checked = isIslandEnabled,
                                onCheckedChange = { enabled ->
                                    islandState.setEnabled(enabled)
                                    if (enabled && DynamicIslandOverlayService.canDrawOverlays(context)) {
                                        DynamicIslandOverlayService.start(context)
                                    } else if (!enabled) {
                                        DynamicIslandOverlayService.stop(context)
                                    }
                                },
                                colors = SwitchDefaults.colors(checkedThumbColor = Color(0xFF54E1C3), checkedTrackColor = Color(0xFF183C36))
                            )
                        }

                        Spacer(modifier = Modifier.height(14.dp))
                        HorizontalDivider(color = Color.White.copy(alpha = 0.08f))
                        Spacer(modifier = Modifier.height(14.dp))

                        // Botão de Detecção Automática do Celular
                        Button(
                            onClick = {
                                val detectedPreset = DeviceCutoutDetector.detectPreset()
                                islandState.setPreset(detectedPreset)
                                syncStatusMessage = "Modelo detectado: ${Build.MANUFACTURER} ${Build.MODEL} -> Preset: ${detectedPreset.name}"
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF54E1C3), contentColor = Color.Black),
                            shape = RoundedCornerShape(10.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Icon(Icons.Default.PhoneAndroid, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Detectar Recorte do Meu Celular", fontWeight = FontWeight.Bold)
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        // Seletor de Modelo de Ilha (Presets)
                        Text("Modelo / Recorte do Celular:", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 13.sp)
                        Spacer(modifier = Modifier.height(8.dp))

                        IslandPreset.ALL_PRESETS.forEach { preset ->
                            val isSelected = preset.type == currentPreset.type
                            Surface(
                                shape = RoundedCornerShape(10.dp),
                                color = if (isSelected) Color(0xFF183C36) else Color(0xFF0F172A),
                                border = if (isSelected) androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF54E1C3)) else null,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 4.dp)
                                    .clip(RoundedCornerShape(10.dp))
                                    .clickable { islandState.setPreset(preset) }
                            ) {
                                Row(
                                    modifier = Modifier.padding(12.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    RadioButton(
                                        selected = isSelected,
                                        onClick = { islandState.setPreset(preset) },
                                        colors = RadioButtonDefaults.colors(selectedColor = Color(0xFF54E1C3))
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Column {
                                        Text(preset.name, fontWeight = FontWeight.Bold, color = Color.White, fontSize = 13.sp)
                                        Text(preset.type.description, color = Color(0xFF94A3B8), fontSize = 11.sp)
                                    }
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(16.dp))
                        HorizontalDivider(color = Color.White.copy(alpha = 0.08f))
                        Spacer(modifier = Modifier.height(16.dp))

                        // Calibração Fina
                        Text("Calibração Fina de Posição (Offsets):", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 13.sp)
                        Spacer(modifier = Modifier.height(12.dp))

                        // Vertical Offset (Y)
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Deslocamento Vertical (Y)", fontSize = 12.sp, color = Color(0xFF94A3B8))
                            Text("$customY dp", fontSize = 12.sp, color = Color(0xFF54E1C3), fontWeight = FontWeight.Bold)
                        }
                        Slider(
                            value = customY.toFloat(),
                            onValueChange = { islandState.setCustomOffsets(customX, it.toInt()) },
                            valueRange = -30f..80f,
                            colors = SliderDefaults.colors(thumbColor = Color(0xFF54E1C3), activeTrackColor = Color(0xFF54E1C3))
                        )

                        // Horizontal Offset (X)
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Deslocamento Horizontal (X)", fontSize = 12.sp, color = Color(0xFF94A3B8))
                            Text("$customX dp", fontSize = 12.sp, color = Color(0xFF54E1C3), fontWeight = FontWeight.Bold)
                        }
                        Slider(
                            value = customX.toFloat(),
                            onValueChange = { islandState.setCustomOffsets(it.toInt(), customY) },
                            valueRange = -100f..100f,
                            colors = SliderDefaults.colors(thumbColor = Color(0xFF54E1C3), activeTrackColor = Color(0xFF54E1C3))
                        )

                        Spacer(modifier = Modifier.height(12.dp))

                        // Action Buttons: Test Animation & Overlay Service
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            OutlinedButton(
                                onClick = { islandState.toggleExpanded() },
                                modifier = Modifier.weight(1f),
                                shape = RoundedCornerShape(10.dp),
                                border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF54E1C3))
                            ) {
                                Text("Testar Toque", color = Color(0xFF54E1C3), fontSize = 12.sp)
                            }

                            Button(
                                onClick = {
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
                                        val intent = Intent(
                                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                            Uri.parse("package:${context.packageName}")
                                        )
                                        context.startActivity(intent)
                                    } else {
                                        DynamicIslandOverlayService.start(context)
                                    }
                                },
                                modifier = Modifier.weight(1f),
                                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1E293B), contentColor = Color.White),
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Text("Overlay Global", fontSize = 12.sp)
                            }
                        }
                    }
                }
            }

            // Future Strava Plugin Card (as requested: "retire o strava dai e coloque na config com a label de futuro plugin")
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
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(38.dp)
                                    .clip(CircleShape)
                                    .background(Color(0xFFFC4C02).copy(alpha = 0.2f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    imageVector = Icons.Default.DirectionsBike,
                                    contentDescription = null,
                                    tint = Color(0xFFFC4C02),
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(
                                    text = "Strava Integration",
                                    fontWeight = FontWeight.Bold,
                                    color = Color.White,
                                    fontSize = 14.sp
                                )
                                Text(
                                    text = "Sincronização de corridas e pedais",
                                    fontSize = 11.sp,
                                    color = Color(0xFF94A3B8)
                                )
                            }
                        }

                        Surface(
                            shape = RoundedCornerShape(6.dp),
                            color = Color(0xFF334155)
                        ) {
                            Text(
                                text = "FUTURO PLUGIN",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF94A3B8),
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                            )
                        }
                    }
                }
            }

            // Logout Button
            item {
                Button(
                    onClick = {
                        coroutineScope.launch {
                            repository.logout()
                            onLogout()
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFFEF4444).copy(alpha = 0.15f),
                        contentColor = Color(0xFFEF4444)
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.ExitToApp, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Sair da Conta")
                }
            }

            item {
                Spacer(modifier = Modifier.height(40.dp))
            }
        }
    }

    // Edit Profile Dialog
    if (showEditProfileDialog) {
        var editName by remember { mutableStateOf(userProfile.name) }
        var editWeight by remember { mutableStateOf(userProfile.currentWeight.toString()) }
        var editTargetWeight by remember { mutableStateOf(userProfile.targetWeight.toString()) }
        var editHeight by remember { mutableStateOf(userProfile.heightMeters.toString()) }
        var autoRecalc by remember { mutableStateOf(true) }
        var editCalories by remember { mutableStateOf(userProfile.targetCalorieIntake.toInt().toString()) }
        var editWater by remember { mutableStateOf(userProfile.targetWaterMilliliters.toString()) }

        val previewProfile = remember(editWeight, editTargetWeight, editHeight, userProfile.goal) {
            val w = editWeight.replace(",", ".").toDoubleOrNull() ?: userProfile.currentWeight
            val tw = editTargetWeight.replace(",", ".").toDoubleOrNull() ?: userProfile.targetWeight
            val h = editHeight.replace(",", ".").toDoubleOrNull() ?: userProfile.heightMeters
            repository.previewRecalculatedProfile(newWeight = w, newHeight = h, newTargetWeight = tw)
        }

        AlertDialog(
            onDismissRequest = { showEditProfileDialog = false },
            title = { Text("Editar Perfil & Metas") },
            text = {
                Column {
                    OutlinedTextField(
                        value = editName,
                        onValueChange = { editName = it },
                        label = { Text("Nome") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = editWeight,
                            onValueChange = { newVal ->
                                editWeight = newVal
                                val w = newVal.replace(",", ".").toDoubleOrNull()
                                val tw = editTargetWeight.replace(",", ".").toDoubleOrNull() ?: userProfile.targetWeight
                                val h = editHeight.replace(",", ".").toDoubleOrNull() ?: userProfile.heightMeters
                                if (autoRecalc && w != null && w in 30.0..300.0) {
                                    val rec = repository.previewRecalculatedProfile(newWeight = w, newHeight = h, newTargetWeight = tw)
                                    editCalories = rec.targetCalorieIntake.toInt().toString()
                                    editWater = rec.targetWaterMilliliters.toString()
                                }
                            },
                            label = { Text("Peso Atual (kg)") },
                            modifier = Modifier.weight(1f),
                            singleLine = true
                        )
                        OutlinedTextField(
                            value = editTargetWeight,
                            onValueChange = { newVal ->
                                editTargetWeight = newVal
                                val tw = newVal.replace(",", ".").toDoubleOrNull()
                                val w = editWeight.replace(",", ".").toDoubleOrNull() ?: userProfile.currentWeight
                                val h = editHeight.replace(",", ".").toDoubleOrNull() ?: userProfile.heightMeters
                                if (autoRecalc && tw != null && tw in 30.0..300.0) {
                                    val rec = repository.previewRecalculatedProfile(newWeight = w, newHeight = h, newTargetWeight = tw)
                                    editCalories = rec.targetCalorieIntake.toInt().toString()
                                    editWater = rec.targetWaterMilliliters.toString()
                                }
                            },
                            label = { Text("Peso Alvo (kg)") },
                            modifier = Modifier.weight(1f),
                            singleLine = true
                        )
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    OutlinedTextField(
                        value = editHeight,
                        onValueChange = { newVal ->
                            editHeight = newVal
                            val h = newVal.replace(",", ".").toDoubleOrNull()
                            val w = editWeight.replace(",", ".").toDoubleOrNull() ?: userProfile.currentWeight
                            val tw = editTargetWeight.replace(",", ".").toDoubleOrNull() ?: userProfile.targetWeight
                            if (autoRecalc && h != null && (h in 1.0..2.5 || h in 100.0..250.0)) {
                                val rec = repository.previewRecalculatedProfile(newWeight = w, newHeight = h, newTargetWeight = tw)
                                editCalories = rec.targetCalorieIntake.toInt().toString()
                                editWater = rec.targetWaterMilliliters.toString()
                            }
                        },
                        label = { Text("Altura (m)") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = "TMB: ${previewProfile.tmb.toInt()} kcal • Contextual: ${previewProfile.targetCalorieIntake.toInt()} kcal • P ${previewProfile.targetProtein.toInt()}g • C ${previewProfile.targetCarbohydrates.toInt()}g • G ${previewProfile.targetFat.toInt()}g",
                        fontSize = 11.sp,
                        color = Color(0xFF54E1C3)
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = editCalories,
                            onValueChange = {
                                editCalories = it
                                autoRecalc = false
                            },
                            label = { Text("Meta Kcal") },
                            modifier = Modifier.weight(1f),
                            singleLine = true
                        )
                        OutlinedTextField(
                            value = editWater,
                            onValueChange = {
                                editWater = it
                                autoRecalc = false
                            },
                            label = { Text("Meta Água (ml)") },
                            modifier = Modifier.weight(1f),
                            singleLine = true
                        )
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val parsedWeight = editWeight.replace(",", ".").toDoubleOrNull() ?: userProfile.currentWeight
                        val parsedTargetWeight = editTargetWeight.replace(",", ".").toDoubleOrNull() ?: userProfile.targetWeight
                        val parsedHeight = editHeight.replace(",", ".").toDoubleOrNull() ?: userProfile.heightMeters
                        val base = repository.previewRecalculatedProfile(
                            newWeight = parsedWeight,
                            newHeight = parsedHeight,
                            newTargetWeight = parsedTargetWeight
                        )
                        val updated = base.copy(
                            name = editName.trim(),
                            targetCalorieIntake = if (autoRecalc) base.targetCalorieIntake else (editCalories.toDoubleOrNull() ?: base.targetCalorieIntake),
                            targetWaterMilliliters = if (autoRecalc) base.targetWaterMilliliters else (editWater.toIntOrNull() ?: base.targetWaterMilliliters)
                        )
                        coroutineScope.launch {
                            if (kotlin.math.abs(parsedWeight - userProfile.currentWeight) >= 0.05) {
                                repository.addWeight(updated.currentWeight, "Atualizado no perfil")
                            }
                            repository.updateProfile(updated)
                            repository.syncPush()
                        }
                        showEditProfileDialog = false
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF54E1C3), contentColor = Color.Black)
                ) {
                    Text("Salvar")
                }
            },
            dismissButton = {
                TextButton(onClick = { showEditProfileDialog = false }) {
                    Text("Cancelar")
                }
            }
        )
    }
}
