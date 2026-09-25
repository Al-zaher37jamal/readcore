package com.example.readmesh

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.File
import java.io.FileNotFoundException

/** Read-only URI for this app's *installed* APK, not an arbitrary filesystem path.
 * Android grants the chosen Sharesheet target temporary read access only.
 */
class ReadMeshApkProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    private fun installedApk(uri: Uri): File {
        if (uri.path != "/installed.apk") throw FileNotFoundException("Unknown file")
        val app = context?.applicationInfo ?: throw FileNotFoundException("No APK")
        if (!app.splitSourceDirs.isNullOrEmpty()) {
            throw FileNotFoundException("Split install is not a standalone APK")
        }
        val file = File(app.sourceDir)
        if (!file.isFile || file.length() == 0L) throw FileNotFoundException("No APK")
        return file
    }

    override fun getType(uri: Uri): String {
        installedApk(uri)
        return "application/vnd.android.package-archive"
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw FileNotFoundException("Read only")
        return ParcelFileDescriptor.open(installedApk(uri), ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun query(uri: Uri, projection: Array<out String>?, selection: String?,
            selectionArgs: Array<out String>?, sortOrder: String?): Cursor {
        val source = installedApk(uri)
        val columns = (projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE))
            .filter { it == OpenableColumns.DISPLAY_NAME || it == OpenableColumns.SIZE }
        val cursor = MatrixCursor(columns.toTypedArray())
        cursor.addRow(columns.map {
            if (it == OpenableColumns.DISPLAY_NAME) "ReadMesh.apk" else source.length()
        }.toTypedArray())
        return cursor
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? =
        throw UnsupportedOperationException("Read only")
    override fun update(uri: Uri, values: ContentValues?, selection: String?,
            selectionArgs: Array<out String>?): Int =
        throw UnsupportedOperationException("Read only")
    override fun delete(uri: Uri, selection: String?,
            selectionArgs: Array<out String>?): Int =
        throw UnsupportedOperationException("Read only")
}
