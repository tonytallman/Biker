//
//  MetricViewModel.swift
//  PhoneUI
//
//  Encapsulates title, value, and optional units for a formatted metric shown in the UI.
//

package struct MetricViewModel {
    package let title: String
    package let value: String
    package let units: String

    package init(title: String, value: String, units: String) {
        self.title = title
        self.value = value
        self.units = units
    }
}
