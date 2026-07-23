#pragma once

#include "core/object/object.h"

class SortingPuzzleSecureStoreBridge : public Object {
	GDCLASS(SortingPuzzleSecureStoreBridge, Object);

protected:
	static void _bind_methods();

public:
	bool ensure_installation_key(const String &installation_id);
	String get_installation_public_key_der(const String &installation_id);
	bool set_installation_id(const String &installation_id);
	String sign_save_operation_hash(const String &operation_hash);
	String sign_installation_payload(const String &payload);
	bool store_player_session(const String &player_id, const String &session_json);
	String load_player_session(const String &player_id);
	bool clear_player_session(const String &player_id);
};

extern "C" void init_sorting_puzzle_secure_store();
extern "C" void deinit_sorting_puzzle_secure_store();
