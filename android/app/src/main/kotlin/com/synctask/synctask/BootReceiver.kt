package com.synctask.synctask

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED ||
            intent?.action == "android.intent.action.QUICKBOOT_POWERON") {
            // Refresh widget on boot with cached data
            SyncTaskWidgetProvider.updateAllWidgets(context, 0, emptyList())
        }
    }
}
