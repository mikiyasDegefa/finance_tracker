package __PKG__

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity // required by local_auth
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/sms")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> {
                        if (granted()) result.success(true) else {
                            ActivityCompat.requestPermissions(
                                this, arrayOf(Manifest.permission.READ_SMS), 1001)
                            result.success(false) // re-check after the user responds
                        }
                    }
                    "fetch" -> {
                        if (!granted()) {
                            result.error("PERMISSION", "READ_SMS denied", null)
                            return@setMethodCallHandler
                        }
                        val senders = call.argument<List<String>>("senders") ?: emptyList()
                        val since = call.argument<Number>("since")?.toLong()
                        result.success(query(senders, since))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun granted() = ContextCompat.checkSelfPermission(
        this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED

    private fun query(senders: List<String>, since: Long?): List<Map<String, Any>> {
        if (senders.isEmpty()) return emptyList() // only configured senders are eligible
        val where = StringBuilder("address IN (${senders.joinToString(",") { "?" }})")
        val args = senders.toMutableList()
        if (since != null) { where.append(" AND date > ?"); args.add(since.toString()) }
        val out = mutableListOf<Map<String, Any>>()
        contentResolver.query(Uri.parse("content://sms/inbox"),
            arrayOf("_id", "address", "body", "date"),
            where.toString(), args.toTypedArray(), "date ASC")?.use { c ->
            while (c.moveToNext()) out.add(mapOf(
                "id" to c.getLong(0), "sender" to c.getString(1),
                "body" to c.getString(2), "date" to c.getLong(3)))
        }
        return out
    }
}
