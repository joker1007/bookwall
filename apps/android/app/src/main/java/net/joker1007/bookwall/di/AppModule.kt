package net.joker1007.bookwall.di

import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    /** Wall-clock provider (epoch millis); swapped for a fixed clock in tests. */
    @Provides
    fun provideClock(): () -> Long = { System.currentTimeMillis() }
}
