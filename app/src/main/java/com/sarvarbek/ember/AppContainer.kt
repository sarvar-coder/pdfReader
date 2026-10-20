package com.sarvarbek.ember

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import com.sarvarbek.ember.data.StorageFiles
import com.sarvarbek.ember.data.WordRepository
import com.sarvarbek.ember.data.db.EmberDatabase
import com.sarvarbek.ember.pdf.PdfService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow

/** The app's single instance of each service. Built once in [App]. */
class AppContainer(context: Context) {
    val db: EmberDatabase = EmberDatabase.build(context)
    val files = StorageFiles(context.filesDir)
    val pdf = PdfService(context)
    val words = WordRepository(db)
    val prefs: SharedPreferences = context.getSharedPreferences("ember", Context.MODE_PRIVATE)

    /** Outlives any screen: for writes that must finish after the user navigates away. */
    val appScope = CoroutineScope(SupervisorJob())

    /** A PDF opened or shared from another app, waiting for the library to import it. Set back to null once consumed. */
    val incomingPdf = MutableStateFlow<Uri?>(null)
}
