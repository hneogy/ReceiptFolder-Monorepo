import Foundation
import SwiftData

// SwiftData handles lightweight schema migration automatically for:
// - Adding new optional fields (receiptImageData, itemImageData)
// - Adding default values to existing fields
// - Removing unique constraints
//
// No explicit VersionedSchema or SchemaMigrationPlan is needed
// for these additive changes. This file is reserved for future
// custom migrations that require manual data transformation.
