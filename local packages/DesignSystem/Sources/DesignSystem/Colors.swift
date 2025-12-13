//
//  Colors.swift
//  PhoneUI
//
//  Color extensions for accessing assets from the package
//

import SwiftUI

extension Color {
    public static var bikerText: Color {
        Color("BikerText", bundle: .module)
    }
    
    public static var bikerTextSecondary: Color {
        Color("BikerTextSecondary", bundle: .module)
    }
    
    public static var bikerBackground: Color {
        Color("BikerBackground", bundle: .module)
    }
    
    public static var bikerSectionBackground: Color {
        Color("BikerSectionBackground", bundle: .module)
    }
    
    public static var bikerSectionText: Color {
        Color("BikerSectionText", bundle: .module)
    }
}
