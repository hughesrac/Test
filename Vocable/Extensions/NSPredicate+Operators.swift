//
//  NSPredicate+Operators.swift
//  Vocable
//
//  Created by Chris Stroud on 3/14/22.
//  Copyright © 2022 WillowTree. All rights reserved.
//

import Foundation

extension NSPredicate {

    static func && (_ lhs: NSPredicate, _ rhs: NSPredicate) -> NSPredicate {
        NSCompoundPredicate(andPredicateWithSubpredicates: [lhs, rhs])
    }

    static func || (_ lhs: NSPredicate, _ rhs: NSPredicate) -> NSPredicate {
        NSCompoundPredicate(orPredicateWithSubpredicates: [lhs, rhs])
    }

    static prefix func ! (_ lhs: NSPredicate) -> NSPredicate {
        NSCompoundPredicate(notPredicateWithSubpredicate: lhs)
    }

    static func &= (_ lhs: inout NSPredicate, _ rhs: NSPredicate) {
        lhs = NSCompoundPredicate(andPredicateWithSubpredicates: [lhs, rhs])
    }

    static func |= (_ lhs: inout NSPredicate, _ rhs: NSPredicate) {
        lhs = NSCompoundPredicate(orPredicateWithSubpredicates: [lhs, rhs])
    }
}
