package com.sarvarbek.ember.navigation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.List
import androidx.compose.material.icons.rounded.Star
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import com.sarvarbek.ember.AppContainer
import com.sarvarbek.ember.features.library.LibraryScreen
import com.sarvarbek.ember.features.stats.StatsScreen
import com.sarvarbek.ember.features.words.WordsScreen
import com.sarvarbek.ember.ui.theme.AppColors
import com.sarvarbek.ember.ui.widgets.FloatingNavBar

// ponytail: core icon set stand-ins (Home/List/Star); swap for book/translate/flame vectors when designed.
private enum class Tab(val label: String, val icon: ImageVector) {
    Library("Library", Icons.Rounded.Home),
    @Suppress("DEPRECATION")
    Words("Words", Icons.Rounded.List),
    Stats("Stats", Icons.Rounded.Star),
}

/** The three top-level tabs under a floating bar. Reader and Notes are pushed over this, not tabs. */
@Composable
fun AppShell(
    container: AppContainer,
    onOpenBook: (String) -> Unit,
    onOpenCollection: (Long, String) -> Unit,
) {
    var tab by rememberSaveable { mutableStateOf(Tab.Library) }
    // Keeps each tab's scroll position etc. while another tab is showing.
    val saveable = rememberSaveableStateHolder()

    Box(Modifier.fillMaxSize().background(AppColors.paper)) {
        saveable.SaveableStateProvider(tab.name) {
            when (tab) {
                Tab.Library -> LibraryScreen(container, onOpenBook, onOpenStats = { tab = Tab.Stats })
                Tab.Words -> WordsScreen(container, onOpenCollection)
                Tab.Stats -> StatsScreen(container)
            }
        }
        FloatingNavBar(
            items = Tab.entries.map { it.label to it.icon },
            selected = tab.ordinal,
            onSelect = { tab = Tab.entries[it] },
            modifier = Modifier.align(Alignment.BottomCenter),
        )
    }
}
