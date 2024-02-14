import App
import CoreData
import Models
import OSLog
import Services
import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ListEntry {
        logger.error("placeholder")
        return ListEntry(date: Date(), items: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (ListEntry) -> ()) {
        logger.error("snapshot")
        Task {
            let entry = ListEntry(date: Date(), items: await getInbox())
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        logger.error("timeline")
        Task {
            var entries: [ListEntry] = []
            let entry = ListEntry(date: Date(), items: await getInbox())
            entries.append(entry)
            
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        }
    }
}

struct ListEntry: TimelineEntry {
    let date: Date
    let items: [ListItem]
}

struct ListItem {
    let id: String
    let title: String
    var omnivoreURL: String

    init(item: Models.LibraryItem) {
      self.id = item.unwrappedID
      self.title = item.unwrappedTitle
      self.omnivoreURL = "omnivore://read/\(item.unwrappedID)"
    }
}

struct ListWidgetEntryView : View {
    @Environment(\.widgetFamily) var family: WidgetFamily

    var entry: Provider.Entry

    var body: some View {
        if entry.items.count == 0 {
            emptyList
        }
        else {
            VStack {
                ForEach(0..<maxCount(), id: \.self, content: { ndx in
                    Text(entry.items[ndx].title)
                })
            }
        }
    }
    
    func maxCount() -> Int {
        if family == .systemLarge {
            return entry.items.count >= 7 ? 7 : entry.items.count
        }
        return entry.items.count >= 3 ? 3 : entry.items.count
    }

    var emptyList: some View {
        VStack(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/, content: {
            Text("Empty List")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("When you save items, they'll appear here.")
                .font(.caption)
                .foregroundColor(.gray)
        })
    }
}

struct ListWidget: Widget {
    let kind: String = "WidgetExtension"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                ListWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                ListWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("List")
        .description("Show items from your library")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@available(iOS 16.0, *)
func filterQuery(predicte: NSPredicate, sort: NSSortDescriptor, limit: Int = 10) async throws -> [ListItem] {
  let context = await Services().dataService.viewContext
  let fetchRequest: NSFetchRequest<Models.LibraryItem> = LibraryItem.fetchRequest()
  fetchRequest.fetchLimit = limit
  fetchRequest.predicate = predicte
  fetchRequest.sortDescriptors = [sort]

  return try context.performAndWait {
    do {
      return try context.fetch(fetchRequest).map { ListItem(item: $0) }
    } catch {
      throw error
    }
  }
}

let logger = Logger(subsystem: "app.omnivore", category: "widget-extension")

func getInbox() async -> [ListItem] {
    let savedAtSort = NSSortDescriptor(key: #keyPath(Models.LibraryItem.savedAt), ascending: false)
    let folderPredicate = NSPredicate(
      format: "%K == %@", #keyPath(Models.LibraryItem.folder), "inbox"
    )

    do {
        let result = try await filterQuery(
            predicte: folderPredicate,
            sort: savedAtSort,
            limit: 10
        )
        return result
    }
    catch {
        return []
    }
}

#Preview(as: .systemMedium) {
    ListWidget()
} timeline: {
    ListEntry(date: .now, items: [])
}
