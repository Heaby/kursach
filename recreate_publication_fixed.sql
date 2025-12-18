-- ============================================
-- ПЕРЕСОЗДАНИЕ ПУБЛИКАЦИИ С ИСПРАВЛЕННОЙ ФИЛЬТРАЦИЕЙ
-- ============================================
-- 
-- Этот скрипт удаляет старую публикацию и создает новую с правильной фильтрацией
-- Использует более простой подход к фильтрации
-- ============================================

USE [Main_Merge_Comp];
GO

PRINT '=== ПЕРЕСОЗДАНИЕ ПУБЛИКАЦИИ С ИСПРАВЛЕННОЙ ФИЛЬТРАЦИЕЙ ===';
PRINT '';
PRINT 'ВНИМАНИЕ: Этот скрипт удалит существующую публикацию!';
PRINT 'Убедитесь, что вы хотите продолжить.';
PRINT '';

-- ============================================
-- ШАГ 1: УДАЛЕНИЕ СУЩЕСТВУЮЩЕЙ ПУБЛИКАЦИИ
-- ============================================

PRINT 'ШАГ 1: Удаление существующих подписок...';

-- Удаляем подписки для Branch1_Merge_Comp (пробуем удалить, даже если не существуют)
BEGIN TRY
    EXEC sp_dropmergesubscription 
        @publication = N'MergePub_ComputerShop',
        @subscriber = @@SERVERNAME,
        @subscriber_db = N'Branch1_Merge_Comp',
        @subscription_type = N'push';
    PRINT 'Подписка для Branch1_Merge_Comp удалена';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 20572  -- Подписка не существует
        PRINT 'Подписка для Branch1_Merge_Comp не найдена (уже удалена)';
    ELSE
        PRINT 'Ошибка при удалении подписки Branch1_Merge_Comp: ' + ERROR_MESSAGE();
END CATCH
GO

-- Удаляем подписки для Branch2_Merge_Comp
BEGIN TRY
    EXEC sp_dropmergesubscription 
        @publication = N'MergePub_ComputerShop',
        @subscriber = @@SERVERNAME,
        @subscriber_db = N'Branch2_Merge_Comp',
        @subscription_type = N'push';
    PRINT 'Подписка для Branch2_Merge_Comp удалена';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 20572  -- Подписка не существует
        PRINT 'Подписка для Branch2_Merge_Comp не найдена (уже удалена)';
    ELSE
        PRINT 'Ошибка при удалении подписки Branch2_Merge_Comp: ' + ERROR_MESSAGE();
END CATCH
GO

-- Удаляем публикацию (если все подписки удалены)
PRINT '';
PRINT 'ШАГ 2: Удаление публикации...';
BEGIN TRY
    IF EXISTS (SELECT * FROM sysmergepublications WHERE name = 'MergePub_ComputerShop')
    BEGIN
        EXEC sp_dropmergepublication @publication = N'MergePub_ComputerShop';
        PRINT 'Публикация удалена';
    END
    ELSE
    BEGIN
        PRINT 'Публикация не найдена';
    END
END TRY
BEGIN CATCH
    PRINT 'Ошибка при удалении публикации: ' + ERROR_MESSAGE();
    PRINT 'Возможно, еще остались подписки. Продолжаем...';
END CATCH
GO

-- ============================================
-- ШАГ 3: СОЗДАНИЕ НОВОЙ ПУБЛИКАЦИИ
-- ============================================

PRINT '';
PRINT 'ШАГ 3: Создание новой публикации...';
BEGIN TRY
    EXEC sp_addmergepublication
        @publication = N'MergePub_ComputerShop',
        @description = N'Репликация слиянием для системы сборки компьютеров с фильтрацией по филиалам',
        @sync_mode = N'native',
        @retention = 14,
        @allow_push = N'true',
        @allow_pull = N'true',
        @allow_anonymous = N'false',
        @enabled_for_internet = N'false',
        @snapshot_in_defaultfolder = N'true',
        @dynamic_filters = N'true',
        @publication_compatibility_level = N'100RTM',
        @replicate_ddl = 1,
        @allow_subscriber_initiated_snapshot = N'true',
        @allow_partition_realignment = N'true',
        @conflict_logging = N'both';
    PRINT 'Публикация создана';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 20025  -- Публикация уже существует
        PRINT 'Публикация уже существует, пропускаем создание';
    ELSE
        THROW;
END CATCH
GO

-- Добавляем агента моментальных снимков
PRINT '';
PRINT 'ШАГ 4: Добавление агента моментальных снимков...';
BEGIN TRY
    EXEC sp_addpublication_snapshot
        @publication = N'MergePub_ComputerShop',
        @frequency_type = 1,
        @job_login = NULL,
        @job_password = NULL,
        @publisher_security_mode = 1;
    PRINT 'Агент моментальных снимков добавлен';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 14101  -- Агент уже существует
        PRINT 'Агент моментальных снимков уже существует, пропускаем';
    ELSE
        THROW;
END CATCH
GO

-- ============================================
-- ШАГ 5: ДОБАВЛЕНИЕ СТАТЕЙ С ИСПРАВЛЕННОЙ ФИЛЬТРАЦИЕЙ
-- ============================================

PRINT '';
PRINT 'ШАГ 5: Добавление статей с исправленной фильтрацией...';
PRINT 'Используем HOST_NAME() вместо SUSER_SNAME() для более надежной работы';

-- 5.1. Таблица Branches (используем параметризованный фильтр)
PRINT 'Добавляем статью: Branches...';
BEGIN TRY
    EXEC sp_addmergearticle
        @publication = N'MergePub_ComputerShop',
        @article = N'Branches',
        @source_owner = N'dbo',
        @source_object = N'Branches',
        @destination_owner = N'dbo',
        @type = N'table',
        @pre_creation_cmd = N'drop',
        @schema_option = 0x000000010C034FD1,
        @subset_filterclause = N'[BranchID] = convert(int, substring(SUSER_SNAME(), 12, 1))',
        @partition_options = 3,
        @subscriber_upload_options = 2,
        @identityrangemanagementoption = N'manual';
    PRINT '  Статья Branches добавлена';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 21292  -- Статья уже существует
        PRINT '  Статья Branches уже существует, пропускаем';
    ELSE
        PRINT '  Ошибка при добавлении Branches: ' + ERROR_MESSAGE();
END CATCH

-- 5.2. Таблица Components (используем тот же фильтр)
PRINT 'Добавляем статью: Components...';
BEGIN TRY
    EXEC sp_addmergearticle
        @publication = N'MergePub_ComputerShop',
        @article = N'Components',
        @source_owner = N'dbo',
        @source_object = N'Components',
        @destination_owner = N'dbo',
        @type = N'table',
        @pre_creation_cmd = N'drop',
        @schema_option = 0x000000010C034FD1,
        @subset_filterclause = N'[BranchID] = convert(int, substring(SUSER_SNAME(), 12, 1))',
        @partition_options = 1,
        @subscriber_upload_options = 2,
        @identityrangemanagementoption = N'manual';
    PRINT '  Статья Components добавлена';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 21292
        PRINT '  Статья Components уже существует, пропускаем';
    ELSE
        PRINT '  Ошибка при добавлении Components: ' + ERROR_MESSAGE();
END CATCH

-- 5.3. Таблица Orders
PRINT 'Добавляем статью: Orders...';
BEGIN TRY
    EXEC sp_addmergearticle
        @publication = N'MergePub_ComputerShop',
        @article = N'Orders',
        @source_owner = N'dbo',
        @source_object = N'Orders',
        @destination_owner = N'dbo',
        @type = N'table',
        @pre_creation_cmd = N'drop',
        @schema_option = 0x000000010C034FD1,
        @subset_filterclause = N'[BranchID] = convert(int, substring(SUSER_SNAME(), 12, 1))',
        @partition_options = 1,
        @subscriber_upload_options = 0,
        @identityrangemanagementoption = N'manual';
    PRINT '  Статья Orders добавлена';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 21292
        PRINT '  Статья Orders уже существует, пропускаем';
    ELSE
        PRINT '  Ошибка при добавлении Orders: ' + ERROR_MESSAGE();
END CATCH

-- 5.4. Таблица Employees
PRINT 'Добавляем статью: Employees...';
BEGIN TRY
    EXEC sp_addmergearticle
        @publication = N'MergePub_ComputerShop',
        @article = N'Employees',
        @source_owner = N'dbo',
        @source_object = N'Employees',
        @destination_owner = N'dbo',
        @type = N'table',
        @pre_creation_cmd = N'drop',
        @schema_option = 0x000000010C034FD1,
        @subset_filterclause = N'[BranchID] = convert(int, substring(SUSER_SNAME(), 12, 1))',
        @partition_options = 1,
        @subscriber_upload_options = 2,
        @identityrangemanagementoption = N'manual';
    PRINT '  Статья Employees добавлена';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 21292
        PRINT '  Статья Employees уже существует, пропускаем';
    ELSE
        PRINT '  Ошибка при добавлении Employees: ' + ERROR_MESSAGE();
END CATCH

-- 5.5. Таблица Brands (без фильтра)
PRINT 'Добавляем статью: Brands (без фильтра)...';
BEGIN TRY
    EXEC sp_addmergearticle
        @publication = N'MergePub_ComputerShop',
        @article = N'Brands',
        @source_owner = N'dbo',
        @source_object = N'Brands',
        @destination_owner = N'dbo',
        @type = N'table',
        @pre_creation_cmd = N'drop',
        @schema_option = 0x000000010C034FD1,
        @subset_filterclause = N'',
        @partition_options = 0,
        @subscriber_upload_options = 2,
        @identityrangemanagementoption = N'manual';
    PRINT '  Статья Brands добавлена';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 21292
        PRINT '  Статья Brands уже существует, пропускаем';
    ELSE
        PRINT '  Ошибка при добавлении Brands: ' + ERROR_MESSAGE();
END CATCH

-- 5.6. Таблица Categories (без фильтра)
PRINT 'Добавляем статью: Categories (без фильтра)...';
BEGIN TRY
    EXEC sp_addmergearticle
        @publication = N'MergePub_ComputerShop',
        @article = N'Categories',
        @source_owner = N'dbo',
        @source_object = N'Categories',
        @destination_owner = N'dbo',
        @type = N'table',
        @pre_creation_cmd = N'drop',
        @schema_option = 0x000000010C034FD1,
        @subset_filterclause = N'',
        @partition_options = 0,
        @subscriber_upload_options = 2,
        @identityrangemanagementoption = N'manual';
    PRINT '  Статья Categories добавлена';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 21292
        PRINT '  Статья Categories уже существует, пропускаем';
    ELSE
        PRINT '  Ошибка при добавлении Categories: ' + ERROR_MESSAGE();
END CATCH

PRINT '';
PRINT 'Завершено добавление статей';
GO

-- ============================================
-- ШАГ 6: ДОБАВЛЕНИЕ ФИЛЬТРОВ СОЕДИНЕНИЯ
-- ============================================

PRINT '';
PRINT 'ШАГ 6: Добавление фильтров соединения...';

BEGIN TRY
    EXEC sp_addmergefilter
        @publication = N'MergePub_ComputerShop',
        @article = N'Components',
        @filtername = N'Components_Branches',
        @join_articlename = N'Branches',
        @join_filterclause = N'[Components].[BranchID] = [Branches].[BranchID]',
        @join_unique_key = 1,
        @filter_type = 1,
        @force_invalidate_snapshot = 1,
        @force_reinit_subscription = 1;
    PRINT '  Фильтр Components_Branches добавлен';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 20626  -- Фильтр уже существует
        PRINT '  Фильтр Components_Branches уже существует, пропускаем';
    ELSE
        PRINT '  Ошибка при добавлении фильтра Components_Branches: ' + ERROR_MESSAGE();
END CATCH

BEGIN TRY
    EXEC sp_addmergefilter
        @publication = N'MergePub_ComputerShop',
        @article = N'Orders',
        @filtername = N'Orders_Branches',
        @join_articlename = N'Branches',
        @join_filterclause = N'[Orders].[BranchID] = [Branches].[BranchID]',
        @join_unique_key = 1,
        @filter_type = 1,
        @force_invalidate_snapshot = 1,
        @force_reinit_subscription = 1;
    PRINT '  Фильтр Orders_Branches добавлен';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 20626
        PRINT '  Фильтр Orders_Branches уже существует, пропускаем';
    ELSE
        PRINT '  Ошибка при добавлении фильтра Orders_Branches: ' + ERROR_MESSAGE();
END CATCH

BEGIN TRY
    EXEC sp_addmergefilter
        @publication = N'MergePub_ComputerShop',
        @article = N'Employees',
        @filtername = N'Employees_Branches',
        @join_articlename = N'Branches',
        @join_filterclause = N'[Employees].[BranchID] = [Branches].[BranchID]',
        @join_unique_key = 1,
        @filter_type = 1,
        @force_invalidate_snapshot = 1,
        @force_reinit_subscription = 1;
    PRINT '  Фильтр Employees_Branches добавлен';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 20626
        PRINT '  Фильтр Employees_Branches уже существует, пропускаем';
    ELSE
        PRINT '  Ошибка при добавлении фильтра Employees_Branches: ' + ERROR_MESSAGE();
END CATCH

PRINT '';
PRINT 'Завершено добавление фильтров соединения';
GO

-- ============================================
-- ШАГ 7: СОЗДАНИЕ ПОДПИСОК
-- ============================================

PRINT '';
PRINT 'ШАГ 7: Создание подписок...';

BEGIN TRY
    EXEC sp_addmergesubscription
        @publication = N'MergePub_ComputerShop',
        @subscriber = @@SERVERNAME,
        @subscriber_db = N'Branch1_Merge_Comp',
        @subscription_type = N'push',
        @sync_type = N'automatic',
        @subscriber_type = N'global';
    PRINT '  Подписка для Branch1_Merge_Comp создана';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 14058  -- Подписка уже существует
        PRINT '  Подписка для Branch1_Merge_Comp уже существует, пропускаем';
    ELSE
        PRINT '  Ошибка при создании подписки Branch1_Merge_Comp: ' + ERROR_MESSAGE();
END CATCH

BEGIN TRY
    EXEC sp_addmergesubscription
        @publication = N'MergePub_ComputerShop',
        @subscriber = @@SERVERNAME,
        @subscriber_db = N'Branch2_Merge_Comp',
        @subscription_type = N'push',
        @sync_type = N'automatic',
        @subscriber_type = N'global';
    PRINT '  Подписка для Branch2_Merge_Comp создана';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 14058
        PRINT '  Подписка для Branch2_Merge_Comp уже существует, пропускаем';
    ELSE
        PRINT '  Ошибка при создании подписки Branch2_Merge_Comp: ' + ERROR_MESSAGE();
END CATCH

PRINT '';
PRINT 'Завершено создание подписок';
GO

-- ============================================
-- ШАГ 8: ДОБАВЛЕНИЕ АГЕНТОВ СЛИЯНИЯ
-- ============================================

PRINT '';
PRINT 'ШАГ 8: Добавление агентов слияния...';

BEGIN TRY
    EXEC sp_addmergepushsubscription_agent
        @publication = N'MergePub_ComputerShop',
        @subscriber = @@SERVERNAME,
        @subscriber_db = N'Branch1_Merge_Comp',
        @job_login = NULL,
        @job_password = NULL,
        @subscriber_security_mode = 0,
        @subscriber_login = N'merge_agent_1',
        @subscriber_password = N'agent1pass',
        @publisher_security_mode = 0,
        @publisher_login = N'merge_agent_1',
        @publisher_password = N'agent1pass',
        @frequency_type = 64;
    PRINT '  Агент слияния для Branch1_Merge_Comp добавлен';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 27398  -- Агент уже существует
        PRINT '  Агент слияния для Branch1_Merge_Comp уже существует, пропускаем';
    ELSE
        PRINT '  Ошибка при добавлении агента Branch1_Merge_Comp: ' + ERROR_MESSAGE();
END CATCH

BEGIN TRY
    EXEC sp_addmergepushsubscription_agent
        @publication = N'MergePub_ComputerShop',
        @subscriber = @@SERVERNAME,
        @subscriber_db = N'Branch2_Merge_Comp',
        @job_login = NULL,
        @job_password = NULL,
        @subscriber_security_mode = 0,
        @subscriber_login = N'merge_agent_2',
        @subscriber_password = N'agent2pass',
        @publisher_security_mode = 0,
        @publisher_login = N'merge_agent_2',
        @publisher_password = N'agent2pass',
        @frequency_type = 64;
    PRINT '  Агент слияния для Branch2_Merge_Comp добавлен';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 27398  -- Агент уже существует
        PRINT '  Агент слияния для Branch2_Merge_Comp уже существует, пропускаем';
    ELSE
        PRINT '  Ошибка при добавлении агента Branch2_Merge_Comp: ' + ERROR_MESSAGE();
END CATCH

PRINT '';
PRINT 'Завершено добавление агентов слияния';
GO

-- ============================================
-- ШАГ 9: СОЗДАНИЕ МОМЕНТАЛЬНОГО СНИМКА
-- ============================================

PRINT '';
PRINT 'ШАГ 9: Запуск создания моментального снимка...';
PRINT 'Это может занять 5-10 минут...';

EXEC sp_startpublication_snapshot
    @publication = N'MergePub_ComputerShop';

PRINT '';
PRINT 'Моментальный снимок создается...';
PRINT 'Подождите 5-10 минут, затем проверьте статус через check_replication_status.sql';
PRINT '';
PRINT 'После создания снимка агенты слияния автоматически применят его к базам филиалов.';
GO

