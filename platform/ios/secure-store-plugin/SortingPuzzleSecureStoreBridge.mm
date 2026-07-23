#import "SortingPuzzleSecureStore-Swift.h"
#include "SortingPuzzleSecureStoreBridge.h"

#include "core/config/engine.h"
#include "core/object/class_db.h"

static SortingPuzzleSecureStoreBridge *singleton = nullptr;

static NSString *to_ns_string(const String &value) {
	return [NSString stringWithUTF8String:value.utf8().get_data()];
}

static String to_godot_string(NSString *value) {
	return value == nil ? String() : String::utf8([value UTF8String]);
}

void SortingPuzzleSecureStoreBridge::_bind_methods() {
	ClassDB::bind_method(D_METHOD("ensure_installation_key", "installation_id"), &SortingPuzzleSecureStoreBridge::ensure_installation_key);
	ClassDB::bind_method(D_METHOD("get_installation_public_key_der", "installation_id"), &SortingPuzzleSecureStoreBridge::get_installation_public_key_der);
	ClassDB::bind_method(D_METHOD("set_installation_id", "installation_id"), &SortingPuzzleSecureStoreBridge::set_installation_id);
	ClassDB::bind_method(D_METHOD("sign_save_operation_hash", "operation_hash"), &SortingPuzzleSecureStoreBridge::sign_save_operation_hash);
	ClassDB::bind_method(D_METHOD("sign_installation_payload", "payload"), &SortingPuzzleSecureStoreBridge::sign_installation_payload);
	ClassDB::bind_method(D_METHOD("store_player_session", "player_id", "session_json"), &SortingPuzzleSecureStoreBridge::store_player_session);
	ClassDB::bind_method(D_METHOD("load_player_session", "player_id"), &SortingPuzzleSecureStoreBridge::load_player_session);
	ClassDB::bind_method(D_METHOD("clear_player_session", "player_id"), &SortingPuzzleSecureStoreBridge::clear_player_session);
}

bool SortingPuzzleSecureStoreBridge::ensure_installation_key(const String &installation_id) {
	return [[SortingPuzzleSecureStore shared] ensureInstallationKey:to_ns_string(installation_id)];
}

String SortingPuzzleSecureStoreBridge::get_installation_public_key_der(const String &installation_id) {
	return to_godot_string([[SortingPuzzleSecureStore shared] installationPublicKeyDER:to_ns_string(installation_id)]);
}

bool SortingPuzzleSecureStoreBridge::set_installation_id(const String &installation_id) {
	return [[SortingPuzzleSecureStore shared] setInstallationID:to_ns_string(installation_id)];
}

String SortingPuzzleSecureStoreBridge::sign_save_operation_hash(const String &operation_hash) {
	return to_godot_string([[SortingPuzzleSecureStore shared] signSaveOperationHash:to_ns_string(operation_hash)]);
}

String SortingPuzzleSecureStoreBridge::sign_installation_payload(const String &payload) {
	return to_godot_string([[SortingPuzzleSecureStore shared] signInstallationPayload:to_ns_string(payload)]);
}

bool SortingPuzzleSecureStoreBridge::store_player_session(const String &player_id, const String &session_json) {
	return [[SortingPuzzleSecureStore shared] storePlayerSession:to_ns_string(player_id) sessionJSON:to_ns_string(session_json)];
}

String SortingPuzzleSecureStoreBridge::load_player_session(const String &player_id) {
	return to_godot_string([[SortingPuzzleSecureStore shared] loadPlayerSession:to_ns_string(player_id)]);
}

bool SortingPuzzleSecureStoreBridge::clear_player_session(const String &player_id) {
	return [[SortingPuzzleSecureStore shared] clearPlayerSession:to_ns_string(player_id)];
}

extern "C" void init_sorting_puzzle_secure_store() {
	ClassDB::register_class<SortingPuzzleSecureStoreBridge>();
	singleton = memnew(SortingPuzzleSecureStoreBridge);
	Engine::get_singleton()->add_singleton(
		Engine::Singleton("SortingPuzzleSecureStoreBridge", singleton)
	);
}

extern "C" void deinit_sorting_puzzle_secure_store() {
	if (singleton == nullptr) {
		return;
	}
	Engine::get_singleton()->remove_singleton("SortingPuzzleSecureStoreBridge");
	memdelete(singleton);
	singleton = nullptr;
}
