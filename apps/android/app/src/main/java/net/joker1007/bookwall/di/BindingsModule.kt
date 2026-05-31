package net.joker1007.bookwall.di

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import net.joker1007.bookwall.data.crypto.KeystoreSecretCipher
import net.joker1007.bookwall.data.crypto.SecretCipher
import net.joker1007.bookwall.data.server.ServerRepository
import net.joker1007.bookwall.data.server.ServerRepositoryImpl
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
}
