package net.joker1007.bookwall.di

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import net.joker1007.bookwall.data.crypto.KeystoreSecretCipher
import net.joker1007.bookwall.data.crypto.SecretCipher
import net.joker1007.bookwall.data.epub.DataStoreEpubSettingsRepository
import net.joker1007.bookwall.data.epub.EpubOpener
import net.joker1007.bookwall.data.epub.EpubPublicationOpener
import net.joker1007.bookwall.data.epub.EpubSettingsRepository
import net.joker1007.bookwall.data.opds.FeedParser
import net.joker1007.bookwall.data.opds.OpdsParser
import net.joker1007.bookwall.data.reader.DataStoreReaderPreferencesRepository
import net.joker1007.bookwall.data.reader.OpdsProgressSyncRepository
import net.joker1007.bookwall.data.reader.ProgressSyncRepository
import net.joker1007.bookwall.data.reader.ReaderPreferencesRepository
import net.joker1007.bookwall.data.reader.ReaderStateRepository
import net.joker1007.bookwall.data.reader.ReaderStateRepositoryImpl
import net.joker1007.bookwall.data.server.ServerRepository
import net.joker1007.bookwall.data.server.ServerRepositoryImpl
import net.joker1007.bookwall.network.ServerImageLoaderFactory
import net.joker1007.bookwall.network.ServerImageLoaderProvider
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class BindingsModule {

    @Binds
    @Singleton
    abstract fun bindSecretCipher(impl: KeystoreSecretCipher): SecretCipher

    @Binds
    @Singleton
    abstract fun bindServerRepository(impl: ServerRepositoryImpl): ServerRepository

    @Binds
    abstract fun bindFeedParser(impl: OpdsParser): FeedParser

    @Binds
    @Singleton
    abstract fun bindServerImageLoaderProvider(impl: ServerImageLoaderFactory): ServerImageLoaderProvider

    @Binds
    abstract fun bindReaderStateRepository(impl: ReaderStateRepositoryImpl): ReaderStateRepository

    @Binds
    abstract fun bindProgressSyncRepository(impl: OpdsProgressSyncRepository): ProgressSyncRepository

    @Binds
    @Singleton
    abstract fun bindReaderPreferencesRepository(
        impl: DataStoreReaderPreferencesRepository,
    ): ReaderPreferencesRepository

    @Binds
    abstract fun bindEpubOpener(impl: EpubPublicationOpener): EpubOpener

    @Binds
    @Singleton
    abstract fun bindEpubSettingsRepository(impl: DataStoreEpubSettingsRepository): EpubSettingsRepository
}
