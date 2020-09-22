//
//  DiffableCollectionViewController.swift
//  DiffableDataSourceForCoreData
//
//  Created by Patrick Steiner on 22.09.20.
//

import UIKit
import CoreData

private extension NSManagedObjectContext {
    func saveOnChanges() {
        guard hasChanges else { return }

        do {
            try save()
        } catch {
            fatalError("Error saving context: \(error)")
        }
    }
}

private extension Item {
    class var defaultRequest: NSFetchRequest<Item> {
        let request: NSFetchRequest<Item> = Item.fetchRequest()

        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(Item.name),
                                                    ascending: true,
                                                    selector: #selector(NSString.caseInsensitiveCompare))]

        return request
    }

    @discardableResult
    class func create(name: String, in context: NSManagedObjectContext) -> Item {
        let item = Item(context: context)

        item.name = name

        return item
    }
}

final class DiffableCollectionViewController: UICollectionViewController {
    private var diffableDataSource: UICollectionViewDiffableDataSource<Int, NSManagedObjectID>!
    private var fetchedResultsController: NSFetchedResultsController<Item>!

    private lazy var managedObjectContext: NSManagedObjectContext = {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate

        return appDelegate.persistentContainer.viewContext
    }()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupDataSource()
        fetchItems()
    }

    // MARK: Data source

    private func setupDataSource() {
        let diffableDataSource = UICollectionViewDiffableDataSource<Int, NSManagedObjectID>(collectionView: collectionView) { (collectionView, indexPath, objectID) -> UICollectionViewCell? in
            guard let item = try? self.managedObjectContext.existingObject(with: objectID) as? Item else {
                fatalError("Managed object should be available")
            }

            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ItemCell", for: indexPath) as! ItemCollectionViewCell

            cell.mainLabel.text = item.name

            return cell
        }

        self.diffableDataSource = diffableDataSource

        collectionView.dataSource = diffableDataSource
    }

    private func fetchItems() {
        fetchedResultsController = NSFetchedResultsController<Item>(fetchRequest: Item.defaultRequest,
                                                                    managedObjectContext: managedObjectContext,
                                                                    sectionNameKeyPath: nil,
                                                                    cacheName: nil)

        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController?.performFetch()
        } catch {
            print("Failed to fetch items with error: \(error)")
        }
    }

    private func createItem(with name: String) {
        Item.create(name: name, in: managedObjectContext)

        managedObjectContext.saveOnChanges()
    }

    private func renameItem(_ item: Item, name: String) {
        item.name = name

        managedObjectContext.saveOnChanges()
    }

    // MARK: UI

    @IBAction func didTapAddButton(_ sender: UIBarButtonItem) {
        presentAddDialog()
    }

    private func presentAddDialog() {
        let alertTitle = "Add Item"
        let alertController = UIAlertController(title: alertTitle, message: nil, preferredStyle: .alert)

        alertController.addTextField { textField in
            textField.placeholder = "Name"
            textField.autocapitalizationType = .sentences
        }

        let addActionTitle = "Add"
        let addAction = UIAlertAction(title: addActionTitle, style: .default) { _ in
            guard let name = alertController.textFields?.first?.text else { return }

            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedName.isEmpty {
                return
            }

            self.createItem(with: trimmedName)
        }

        alertController.addAction(addAction)

        let cancelActionTitle = "Cancel"
        let cancelAction = UIAlertAction(title: cancelActionTitle, style: .cancel)
        alertController.addAction(cancelAction)

        present(alertController, animated: true)
    }

    private func presentRenameDialog(item: Item) {
        let alertTitle = "Rename Item"
        let alertController = UIAlertController(title: alertTitle, message: nil, preferredStyle: .alert)

        alertController.addTextField { textField in
            textField.placeholder = "Name"
            textField.autocapitalizationType = .words
            textField.clearButtonMode = .always
            textField.text = item.name
        }

        let renameActionTitle = "Rename"
        let renameAction = UIAlertAction(title: renameActionTitle, style: .default) { _ in
            guard let name = alertController.textFields?.first?.text else { return }

            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedName.isEmpty {
                return
            }

            self.renameItem(item, name: trimmedName)
        }

        alertController.addAction(renameAction)

        let cancelActionTitle = "Cancel"
        let cancelAction = UIAlertAction(title: cancelActionTitle, style: .cancel)
        alertController.addAction(cancelAction)

        present(alertController, animated: true)
    }

    // MARK: UITableViewDelegate

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = fetchedResultsController?.object(at: indexPath) else { return }

        presentRenameDialog(item: item)
    }
}

extension DiffableCollectionViewController: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        guard let dataSource = collectionView.dataSource as? UICollectionViewDiffableDataSource<Int, NSManagedObjectID> else {
            assertionFailure("The data source has not implemented snapshot support while it should")
            return
        }

        let shouldAnimate = collectionView.numberOfSections != 0

        dataSource.apply(snapshot as NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>, animatingDifferences: shouldAnimate)
    }
}
