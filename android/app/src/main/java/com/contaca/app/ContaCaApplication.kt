package com.contaca.app

import android.app.Application
import com.contaca.app.data.local.DatabaseHelper
import com.contaca.app.data.repository.ContaCaRepository
import com.contaca.app.service.NotificationHelper

class ContaCaApplication : Application() {

    lateinit var database: DatabaseHelper
    lateinit var repository: ContaCaRepository

    companion object {
        lateinit var instance: ContaCaApplication
            private set
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        database = DatabaseHelper(this)
        repository = ContaCaRepository(this, database)
        NotificationHelper.createNotificationChannels(this)
    }
}
