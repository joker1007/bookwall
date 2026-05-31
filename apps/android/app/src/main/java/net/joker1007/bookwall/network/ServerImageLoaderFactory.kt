package net.joker1007.bookwall.network

import android.content.Context
import coil3.ImageLoader
import coil3.disk.DiskCache
import coil3.disk.directory
import coil3.network.okhttp.OkHttpNetworkFetcherFactory
import dagger.hilt.android.qualifiers.ApplicationContext
import net.joker1007.bookwall.data.server.OpdsServer
import okhttp3.Call
import java.util.concurrent.ConcurrentHashMap
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Builds (and caches) a Coil [ImageLoader] per OPDS server. Each loader uses
 * that server's OkHttp client, so cover/thumbnail requests inherit Basic auth
 * and self-signed-certificate trust, and shares a disk cache for thumbnails.
 */
@Singleton
class ServerImageLoaderFactory @Inject constructor(
    @ApplicationContext private val context: Context,
    private val clientFactory: OkHttpClientFactory,
) : ServerImageLoaderProvider {
    private val loaders = ConcurrentHashMap<Long, ImageLoader>()

    override fun forServer(server: OpdsServer): ImageLoader = loaders.getOrPut(server.id) {
        ImageLoader.Builder(context)
            .components {
                add(
                    OkHttpNetworkFetcherFactory(
                        callFactory = { clientFactory.forServer(server) as Call.Factory },
                    ),
                )
            }
            .diskCache {
                DiskCache.Builder()
                    .directory(context.cacheDir.resolve("opds_images"))
                    .maxSizeBytes(MAX_DISK_CACHE_BYTES)
                    .build()
            }
            .build()
    }

    private companion object {
        const val MAX_DISK_CACHE_BYTES = 256L * 1024 * 1024
    }
}
