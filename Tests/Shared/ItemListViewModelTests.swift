import Foundation
import Testing
@testable import MurderMystery

@MainActor
struct ItemListViewModelTests {
    @Test func loadPopulatesItems() {
        let repository = MockItemRepository(items: [Item(title: "A"), Item(title: "B")])
        let viewModel = ItemListViewModel(repository: repository)

        viewModel.load()

        #expect(viewModel.items.count == 2)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func deleteRemovesItem() {
        let repository = MockItemRepository(items: [Item(title: "A"), Item(title: "B")])
        let viewModel = ItemListViewModel(repository: repository)
        viewModel.load()

        viewModel.delete(at: IndexSet(integer: 0))

        #expect(viewModel.items.map(\.title) == ["B"])
    }

    @Test func loadFailureSetsErrorMessage() {
        let repository = MockItemRepository()
        repository.error = TestError()
        let viewModel = ItemListViewModel(repository: repository)

        viewModel.load()

        #expect(viewModel.errorMessage != nil)
    }
}

@MainActor
struct ItemEditorViewModelTests {
    @Test func blankTitleCannotBeSaved() {
        let viewModel = ItemEditorViewModel(repository: MockItemRepository())
        viewModel.title = "   "

        #expect(!viewModel.canSave)
    }

    @Test func savingNewItemInserts() {
        let repository = MockItemRepository()
        let viewModel = ItemEditorViewModel(repository: repository)
        viewModel.title = "  Hello  "

        #expect(viewModel.save())
        #expect(repository.items.map(\.title) == ["Hello"])
    }

    @Test func savingExistingItemUpdatesInPlace() {
        let item = Item(title: "Old")
        let repository = MockItemRepository(items: [item])
        let viewModel = ItemEditorViewModel(repository: repository, item: item)
        viewModel.title = "New"

        #expect(viewModel.save())
        #expect(item.title == "New")
        #expect(repository.saveCount == 1)
    }
}
