package com.forma.app

import android.app.Application
import com.forma.app.data.local.DatabaseHelper
import com.forma.app.data.repository.FormaRepository
import com.forma.app.service.NotificationHelper

class FormaApplication : Application() {

    lateinit var database: DatabaseHelper
    lateinit var repository: FormaRepository

    companion object {
        lateinit var instance: FormaApplication
            private set
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        database = DatabaseHelper(this)
        repository = FormaRepository(this, database)
        NotificationHelper.createNotificationChannels(this)
    }
}
