package net.joker1007.bookwall.feature.epubreader

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import net.joker1007.bookwall.data.epub.EpubSettings
import net.joker1007.bookwall.data.epub.EpubSettingsRepository
import net.joker1007.bookwall.data.epub.EpubTheme
import javax.inject.Inject

data class EpubChromeState(
    val menuVisible: Boolean = false,
    val settingsVisible: Boolean = false,
    val tocVisible: Boolean = false,
)

@HiltViewModel
class EpubReaderViewModel @Inject constructor(
    private val settingsRepository: EpubSettingsRepository,
) : ViewModel() {

    val settings: StateFlow<EpubSettings> = settingsRepository.settings
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), EpubSettings())

    private val _chrome = MutableStateFlow(EpubChromeState())
    val chrome: StateFlow<EpubChromeState> = _chrome.asStateFlow()

    fun toggleMenu() = _chrome.update { it.copy(menuVisible = !it.menuVisible) }

    fun openSettings() = _chrome.update { it.copy(settingsVisible = true) }

    fun closeSettings() = _chrome.update { it.copy(settingsVisible = false) }

    fun openToc() = _chrome.update { it.copy(tocVisible = true) }

    fun closeToc() = _chrome.update { it.copy(tocVisible = false) }

    fun setTheme(theme: EpubTheme) = viewModelScope.launch { settingsRepository.setTheme(theme) }

    fun setFontSizePercent(percent: Int) = viewModelScope.launch { settingsRepository.setFontSizePercent(percent) }

    fun setVerticalText(enabled: Boolean) = viewModelScope.launch { settingsRepository.setVerticalText(enabled) }

    fun setScroll(enabled: Boolean) = viewModelScope.launch { settingsRepository.setScroll(enabled) }
}
