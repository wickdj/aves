package deckers.thibault.aves.channel.calls

import android.app.Activity
import deckers.thibault.aves.channel.calls.Coresult.Companion.safe
import deckers.thibault.aves.model.provider.MediaStoreImageProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch

class MediaStoreHandler(private val activity: Activity) : MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkObsoleteContentIds" -> GlobalScope.launch(Dispatchers.IO) { safe(call, result, ::checkObsoleteContentIds) }
            "checkObsoletePaths" -> GlobalScope.launch(Dispatchers.IO) { safe(call, result, ::checkObsoletePaths) }
            else -> result.notImplemented()
        }
    }

    private fun checkObsoleteContentIds(call: MethodCall, result: MethodChannel.Result) {
        val knownContentIds = call.argument<List<Int>>("knownContentIds")
        if (knownContentIds == null) {
            result.error("checkObsoleteContentIds-args", "failed because of missing arguments", null)
            return
        }
        result.success(MediaStoreImageProvider().checkObsoleteContentIds(activity, knownContentIds))
    }

    private fun checkObsoletePaths(call: MethodCall, result: MethodChannel.Result) {
        val knownPathById = call.argument<Map<Int, String>>("knownPathById")
        if (knownPathById == null) {
            result.error("checkObsoletePaths-args", "failed because of missing arguments", null)
            return
        }
        result.success(MediaStoreImageProvider().checkObsoletePaths(activity, knownPathById))
    }

    companion object {
        const val CHANNEL = "deckers.thibault/aves/mediastore"
    }
}