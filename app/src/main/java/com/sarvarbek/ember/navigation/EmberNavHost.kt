package com.sarvarbek.ember.navigation

import androidx.compose.animation.ContentTransform
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.runtime.Composable
import androidx.lifecycle.viewmodel.navigation3.rememberViewModelStoreNavEntryDecorator
import androidx.navigation3.runtime.NavKey
import androidx.navigation3.runtime.entryProvider
import androidx.navigation3.runtime.rememberNavBackStack
import androidx.navigation3.runtime.rememberSaveableStateHolderNavEntryDecorator
import androidx.navigation3.ui.NavDisplay
import com.sarvarbek.ember.AppContainer
import com.sarvarbek.ember.features.notes.NoteScreen
import com.sarvarbek.ember.features.reader.ReaderScreen
import com.sarvarbek.ember.features.words.CollectionScreen

private fun push(): ContentTransform =
    slideInHorizontally { it } togetherWith slideOutHorizontally { -it / 4 }

private fun pop(): ContentTransform =
    slideInHorizontally { -it / 4 } togetherWith slideOutHorizontally { it }

/**
 * The app's one back stack. Push = add, pop = removeLastOrNull. Screens get navigation as lambdas,
 * so features never import this package or each other.
 */
@Composable
fun EmberNavHost(container: AppContainer) {
    val backStack = rememberNavBackStack(Route.Shell)
    fun go(route: NavKey) = backStack.add(route)
    fun back() = backStack.removeLastOrNull()

    NavDisplay(
        backStack = backStack,
        onBack = { back() },
        entryDecorators = listOf(
            rememberSaveableStateHolderNavEntryDecorator(),
            // Each entry gets its own ViewModelStore, so two Readers never share a ViewModel.
            rememberViewModelStoreNavEntryDecorator(),
        ),
        transitionSpec = { push() },
        popTransitionSpec = { pop() },
        predictivePopTransitionSpec = { pop() },
        entryProvider = entryProvider {
            entry<Route.Shell> {
                AppShell(
                    container = container,
                    onOpenBook = { go(Route.Reader(it)) },
                    onOpenCollection = { id, name -> go(Route.WordCollection(id, name)) },
                )
            }
            entry<Route.Reader> { r ->
                ReaderScreen(
                    container = container,
                    bookId = r.bookId,
                    onBack = { back() },
                    onOpenNotes = { id, title -> go(Route.Notes(id, title)) },
                )
            }
            entry<Route.Notes> { r ->
                NoteScreen(container, r.bookId, r.title, onBack = { back() })
            }
            entry<Route.WordCollection> { r ->
                CollectionScreen(container, r.collectionId, r.name, onBack = { back() })
            }
        },
    )
}
