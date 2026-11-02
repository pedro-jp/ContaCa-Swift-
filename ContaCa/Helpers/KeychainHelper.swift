//
//  KeychainHelper.swift
//  ContaCa
//
//  Created by João Pedro on 11/02/26.
//

import Foundation
import Security

public final class KeychainHelper {
    public static let shared = KeychainHelper()
    private let serviceName = "com.contaca.app.auth"
    
    private init() {}
    
    @discardableResult
    public func save(key: String, string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(key: key, data: data)
    }
    
    @discardableResult
    public func save(key: String, data: Data) -> Bool {
        // Remove item anterior se já existir
        delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            // Fallback redundante para UserDefaults caso Keychain esteja restrito em ambiente simulado
            UserDefaults.standard.set(data, forKey: "kc_fallback_\(key)")
            return false
        }
        return true
    }
    
    public func loadString(key: String) -> String? {
        guard let data = load(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    public func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return data
        }
        
        // Verifica se há fallback no UserDefaults
        return UserDefaults.standard.data(forKey: "kc_fallback_\(key)")
    }
    
    @discardableResult
    public func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: "kc_fallback_\(key)")
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
