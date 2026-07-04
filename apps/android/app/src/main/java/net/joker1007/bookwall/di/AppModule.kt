package net.joker1007.bookwall.di

import android.content.Context
import androidx.work.WorkManager
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import net.joker1007.bookwall.data.cache.BookCacheFileStore
import java.io.File
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    /** Wall-clock provider (epoch millis); swapped for a fixed clock in tests. */
    @Provides
    fun provideClock(): () -> Long = { System.currentTimeMillis() }

    @Provides
    @Singleton
    fun provideWorkManager(@ApplicationContext context: Context): WorkManager =
        WorkManager.getInstance(context)

    @Provides
    @Singleton
    fun provideBookCacheFileStore(@ApplicationContext context: Context): BookCacheFileStore =
        BookCacheFileStore(File(context.filesDir, "book_cache"))
}
