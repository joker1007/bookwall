package net.joker1007.bookwall.di

import android.content.Context
import androidx.room.Room
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import net.joker1007.bookwall.data.db.BookwallDatabase
import net.joker1007.bookwall.data.db.EpubProgressDao
import net.joker1007.bookwall.data.db.OpdsServerDao
import net.joker1007.bookwall.data.db.ReaderStateDao
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): BookwallDatabase =
        Room.databaseBuilder(context, BookwallDatabase::class.java, BookwallDatabase.NAME)
            .fallbackToDestructiveMigration(dropAllTables = true)
            .build()

    @Provides
    fun provideOpdsServerDao(database: BookwallDatabase): OpdsServerDao = database.opdsServerDao()

    @Provides
    fun provideReaderStateDao(database: BookwallDatabase): ReaderStateDao = database.readerStateDao()

    @Provides
    fun provideEpubProgressDao(database: BookwallDatabase): EpubProgressDao = database.epubProgressDao()
}
