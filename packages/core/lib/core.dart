/// Shared entities, repository contracts, and Firestore/Auth datasources
/// used by both `pos_app` and `manager_app`.
library;

export 'di/register_core_dependencies.dart';

export 'entities/app_role.dart';
export 'entities/app_user.dart';
export 'entities/menu_item.dart';

export 'failures/failure.dart';
export 'failures/firebase_failure_mapper.dart';

export 'repositories/auth_repository.dart';
export 'repositories/menu_repository.dart';

export 'datasources/firebase_auth_datasource.dart';
export 'datasources/firestore_menu_datasource.dart';
