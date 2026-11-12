import CoreData

/// The one Core Data entity; attributes are optional or defaulted so CloudKit can be added later.
@objc(Card)
final class Card: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var urlString: String?
    @NSManaged var title: String?
    @NSManaged var siteName: String?
    @NSManaged var imageData: Data?
    @NSManaged var kindRaw: Int16
    @NSManaged var estMinutes: Int16
    @NSManaged var savedAt: Date?
    @NSManaged var dueAt: Date?
    @NSManaged var statusRaw: Int16
    @NSManaged var pressedAt: Date?
    @NSManaged var crumbledAt: Date?
    @NSManaged var rescuedAt: Date?
    @NSManaged var note: String?
    @NSManaged var finishRaw: Int16
    @NSManaged var sealSeed: Int32
    @NSManaged var customTitle: String?
    @NSManaged var metaAttempts: Int16
    @NSManaged var metaLastAttemptAt: Date?
}

extension Card {
    /// Value copy for the UI. Nil if the row is missing required fields.
    var record: CardRecord? {
        guard let id = self.id,
              let urlString = self.urlString,
              let url = URL(string: urlString),
              let savedAt = self.savedAt,
              let dueAt = self.dueAt else { return nil }
        return CardRecord(
            id: id,
            url: url,
            title: title,
            siteName: siteName,
            imageData: imageData,
            kind: CardKind(rawValue: kindRaw) ?? .article,
            estMinutes: estMinutes > 0 ? Int(estMinutes) : nil,
            savedAt: savedAt,
            dueAt: dueAt,
            status: CardStatus(rawValue: statusRaw) ?? .pending,
            pressedAt: pressedAt,
            crumbledAt: crumbledAt,
            rescuedAt: rescuedAt,
            note: note,
            finish: CardFinish(rawValue: finishRaw) ?? .none,
            sealSeed: sealSeed,
            customTitle: customTitle
        )
    }
}

final class PersistenceController {
    #if DEBUG
    /// UI tests (`-uitest`) get a throwaway in-memory store so they never touch real saved links.
    /// (Also compiled into the widget, so this cannot call into app-only code.)
    static let shared = PersistenceController(inMemory: ProcessInfo.processInfo.arguments.contains("-uitest"))
    #else
    static let shared = PersistenceController()
    #endif

    /// Built once per process. Building it twice makes Core Data complain about duplicate entities.
    private static let model: NSManagedObjectModel = makeModel()

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Pressed", managedObjectModel: PersistenceController.model)

        let description: NSPersistentStoreDescription
        if inMemory {
            description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
        } else {
            let base = AppGroup.containerURL
                ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            description = NSPersistentStoreDescription(url: base.appendingPathComponent("Pressed.sqlite"))
        }
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data failed to load: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    private static func makeModel() -> NSManagedObjectModel {
        func attribute(_ name: String,
                       _ type: NSAttributeType,
                       defaultValue: Any? = nil,
                       external: Bool = false) -> NSAttributeDescription {
            let description = NSAttributeDescription()
            description.name = name
            description.attributeType = type
            description.isOptional = true
            if let defaultValue { description.defaultValue = defaultValue }
            if external { description.allowsExternalBinaryDataStorage = true }
            return description
        }

        let entity = NSEntityDescription()
        entity.name = "Card"
        entity.managedObjectClassName = "Card"
        entity.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("urlString", .stringAttributeType),
            attribute("title", .stringAttributeType),
            attribute("siteName", .stringAttributeType),
            attribute("imageData", .binaryDataAttributeType, external: true),
            attribute("kindRaw", .integer16AttributeType, defaultValue: 0),
            attribute("estMinutes", .integer16AttributeType, defaultValue: 0),
            attribute("savedAt", .dateAttributeType),
            attribute("dueAt", .dateAttributeType),
            attribute("statusRaw", .integer16AttributeType, defaultValue: 0),
            attribute("pressedAt", .dateAttributeType),
            attribute("crumbledAt", .dateAttributeType),
            attribute("rescuedAt", .dateAttributeType),
            attribute("note", .stringAttributeType),
            attribute("finishRaw", .integer16AttributeType, defaultValue: 0),
            attribute("sealSeed", .integer32AttributeType, defaultValue: 0),
            attribute("customTitle", .stringAttributeType),
            attribute("metaAttempts", .integer16AttributeType, defaultValue: 0),
            attribute("metaLastAttemptAt", .dateAttributeType)
        ]

        let model = NSManagedObjectModel()
        model.entities = [entity]
        return model
    }
}
