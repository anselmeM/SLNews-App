package com.slnews.mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget: the current top headline, refreshed by the app whenever
 * the For You feed changes. Tapping opens that story, or Following when no
 * article id has been written yet.
 */
class SlNewsWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views = RemoteViews(context.packageName, R.layout.slnews_widget).apply {
        setTextViewText(
            R.id.widget_title,
            widgetData.getString("widget_title", null)
                ?: context.getString(R.string.widget_empty_title),
        )
        setTextViewText(
            R.id.widget_meta,
            widgetData.getString("widget_meta", null)
                ?: context.getString(R.string.widget_meta_default),
        )
        val articleId = widgetData.getString("widget_article_id", null)
        val uri =
            if (!articleId.isNullOrBlank()) Uri.parse("slnews://article/$articleId")
            else Uri.parse("slnews://following")
        setOnClickPendingIntent(
            R.id.widget_root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri),
        )
      }
      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
