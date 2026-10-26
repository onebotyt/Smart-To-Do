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

            // Click container opens MainActivity
            val mainIntent = Intent(context, MainActivity::class.java)
            val mainPendingIntent = PendingIntent.getActivity(
                context,
                0,
                mainIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, mainPendingIntent)

            // Click (+) button opens MainActivity with action to add task
            val addIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.synctask.CREATE_TASK"
            }
            val addPendingIntent = PendingIntent.getActivity(
                context,
                1,
                addIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_add_btn, addPendingIntent)

            // Update bold pending counter badge (matching Image 2)
            views.setTextViewText(R.id.widget_pending_badge, pendingCount.toString())

            val rowIds = intArrayOf(
                R.id.widget_task_row_1,
                R.id.widget_task_row_2,
                R.id.widget_task_row_3,
                R.id.widget_task_row_4,
                R.id.widget_task_row_5,
                R.id.widget_task_row_6
            )

            val textIds = intArrayOf(
                R.id.widget_task_text_1,
                R.id.widget_task_text_2,
                R.id.widget_task_text_3,
                R.id.widget_task_text_4,
                R.id.widget_task_text_5,
                R.id.widget_task_text_6
            )

            if (tasks.isEmpty()) {
                views.setViewVisibility(R.id.widget_empty_text, View.VISIBLE)
                for (rowId in rowIds) {
                    views.setViewVisibility(rowId, View.GONE)
                }
            } else {
                views.setViewVisibility(R.id.widget_empty_text, View.GONE)
                for (i in rowIds.indices) {
                    if (i < tasks.size) {
                        views.setViewVisibility(rowIds[i], View.VISIBLE)
                        views.setTextViewText(textIds[i], tasks[i])
                    } else {
                        views.setViewVisibility(rowIds[i], View.GONE)
                    }
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
