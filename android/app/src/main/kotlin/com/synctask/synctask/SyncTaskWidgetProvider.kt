package com.synctask.synctask

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

class SyncTaskWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, widgetId, 0, emptyList())
        }
    }

    companion object {
        fun updateAllWidgets(context: Context, pendingCount: Int, tasks: List<String>) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, SyncTaskWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (widgetId in allWidgetIds) {
                updateAppWidget(context, appWidgetManager, widgetId, pendingCount, tasks)
            }
        }

        private fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            pendingCount: Int,
            tasks: List<String>
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_sync_task)

            // Click opens MainActivity
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            // Update pending badge
            views.setTextViewText(R.id.widget_pending_badge, "$pendingCount Pending")

            if (tasks.isEmpty()) {
                views.setTextViewText(R.id.widget_task_1, "No pending tasks")
                views.setViewVisibility(R.id.widget_task_1, View.VISIBLE)
                views.setViewVisibility(R.id.widget_task_2, View.GONE)
                views.setViewVisibility(R.id.widget_task_3, View.GONE)
            } else {
                views.setTextViewText(R.id.widget_task_1, "• " + tasks[0])
                views.setViewVisibility(R.id.widget_task_1, View.VISIBLE)

                if (tasks.size > 1) {
                    views.setTextViewText(R.id.widget_task_2, "• " + tasks[1])
                    views.setViewVisibility(R.id.widget_task_2, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_task_2, View.GONE)
                }

                if (tasks.size > 2) {
                    views.setTextViewText(R.id.widget_task_3, "• " + tasks[2])
                    views.setViewVisibility(R.id.widget_task_3, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_task_3, View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
