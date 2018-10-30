import Foundation
import UIKit

class PrinterManager {
    
    static let instance = PrinterManager()
    
    var delegates: Array<PrinterManagerDelegate> = []
    
    private(set) var printers: [[String: Any]] = []
    
    // Update list of printers stored in memory
    // Information came from iOS App and we need to update
    // what we have in memory.
    // Listeners will be notified of changes
    func updatePrinters(printers: [[String: Any]]) {        
        let previousDefaultPrinter = defaultPrinter()
        
        self.printers = printers

        let currentDefaultPrinter = defaultPrinter()

        if !samePrinter(printerL: previousDefaultPrinter, printerR: currentDefaultPrinter) {
            // Update OctoPrintClient to point to new default printer
            OctoPrintClient.instance.configure()

            // Notify that default printer has changed
            for delegate in delegates {
                delegate.defaultPrinterChanged(newDefault: currentDefaultPrinter)
            }
        }
        // Notify listeners that printers have changed
        for delegate in delegates {
            delegate.printersChanged()
        }
    }
    
    // Apple Watch selected new default printer. Update locally and request
    // iOS App to reflect new change
    func changeDefaultPrinter(printerName: String) {
        var currentDefaultPrinter: [String: Any]?
        // Update local printers to have new default printer
        for (index, printer) in printers.enumerated() {
            let isNewDefault = name(printer: printer) == printerName
            if isNewDefault {
                currentDefaultPrinter = printers[index]
            }
            printers[index]["isDefault"] = isNewDefault
        }
        // Request iOS App to update selected printer
        WatchSessionManager.instance.updateApplicationContext(context: ["selected_printer" : printerName])

        if let currentDefaultPrinter = currentDefaultPrinter {
            // Notify that default printer has changed
            for delegate in delegates {
                delegate.defaultPrinterChanged(newDefault: currentDefaultPrinter)
            }
        }
    }
    
    // Returns default printer. This is the selected printer by the user
    func defaultPrinter() -> [String: Any]? {
        for printer in printers {
            if isDefault(printer: printer) {
                return printer
            }
        }
        return nil
    }
    
    // We only receive files when receiving a camera image. Get the file content
    // before returning since the file will be gone after this. Notify listeners
    // that a new UIImage has been received
    func fileReceived(file: URL, metadata: [String: Any]?) {
        do {
            if let metadata = metadata, let cameraId = metadata["cameraId"] as? String {
                let image = try UIImage(data: Data(contentsOf: file))
                // Notify listeners that reading image from receive file was successful
                for delegate in delegates {
                    delegate.imageReceived(image: image, cameraId: cameraId)
                }
            }
        }
        catch {
            NSLog("Error reading image from file. Error: \(error)")
            // Notify listeners that reading image from receive file failed
            for delegate in delegates {
                delegate.imageReceived(image: nil, cameraId: "-1")
            }
        }
    }
    
    
    // MARK: - Delegates operations
    
    func remove(printerManagerDelegate toRemove: PrinterManagerDelegate) {
        delegates.removeAll(where: { $0 === toRemove })
    }

    // MARK: - Printer Properties - parsed
    
    func name(printer: [String: Any]) -> String {
        return printer["name"] as! String
    }

    func hostname(printer: [String: Any]) -> String {
        return printer["hostname"] as! String
    }

    func apiKey(printer: [String: Any]) -> String {
        return printer["apiKey"] as! String
    }

    func isDefault(printer: [String: Any]) -> Bool {
        return printer["isDefault"] as! Bool
    }
    
    func username(printer: [String: Any]) -> String? {
        return printer["username"] as? String
    }

    func password(printer: [String: Any]) -> String? {
        return printer["password"] as? String
    }

    func cameras(printer: [String: Any]) -> [(url: String, orientation: Int)]? {
        if let cameras = printer["cameras"] as? Array<Dictionary<String, Any>> {
            var result: [(url: String, orientation: Int)] = Array()
            for camera in cameras {
                result.append((url: camera["url"] as! String, orientation: camera["orientation"] as! Int))
            }
            return result
        }
        return nil
    }
    
    // MARK: - Private functions
    
    // Compare of two printers are equal
    fileprivate func samePrinter(printerL: [String: Any]?, printerR: [String: Any]?) -> Bool {
        if printerL == nil && printerR == nil {
            return true
        }
        
        if printerL != nil && printerR == nil {
            return false
        }

        if printerL == nil && printerR != nil {
            return false
        }
        
        return name(printer: printerL!) == name(printer: printerR!) && hostname(printer: printerL!) == hostname(printer: printerR!) && apiKey(printer: printerL!) == apiKey(printer: printerR!) && isDefault(printer: printerL!) == isDefault(printer: printerR!)
    }
}