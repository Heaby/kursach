-- ============================================
-- АЛЬТЕРНАТИВНОЕ РЕШЕНИЕ: ПРОБЛЕМА С ФИЛЬТРОМ SUSER_SNAME()
-- ============================================
-- 
-- Проблема может быть в том, что фильтр SUSER_SNAME() не работает корректно
-- для автоматической фильтрации. Вместо этого используем параметризованные фильтры.
-- 
-- ВАЖНО: Этот скрипт пересоздает публикацию с правильными настройками!
-- ============================================

USE [Main_Merge_Comp];
GO

PRINT '=== АЛЬТЕРНАТИВНОЕ РЕШЕНИЕ: ПЕРЕСОЗДАНИЕ ПУБЛИКАЦИИ ===';
PRINT '';
PRINT 'ВНИМАНИЕ: Этот скрипт удалит существующую публикацию!';
PRINT 'Если вы хотите продолжить, раскомментируйте код ниже.';
PRINT '';
GO

/*
-- ============================================
-- ШАГ 1: УДАЛЕНИЕ СУЩЕСТВУЮЩЕЙ ПУБЛИКАЦИИ
-- ============================================

-- Удаляем подписки
EXEC sp_dropmergesubscription 
    @publication = N'MergePub_ComputerShop',
    @subscriber = @@SERVERNAME,
    @subscriber_db = N'Branch1_Merge_Comp',
    @subscription_type = N'push';

EXEC sp_dropmergesubscription 
    @publication = N'MergePub_ComputerShop',
    @subscriber = @@SERVERNAME,
    @subscriber_db = N'Branch2_Merge_Comp',
    @subscription_type = N'push';

-- Удаляем публикацию
EXEC sp_dropmergepublication @publication = N'MergePub_ComputerShop';

GO

-- ============================================
-- ШАГ 2: СОЗДАНИЕ НОВОЙ ПУБЛИКАЦИИ С ПАРАМЕТРИЗОВАННЫМИ ФИЛЬТРАМИ
-- ============================================

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

GO

-- Добавляем агента моментальных снимков
EXEC sp_addpublication_snapshot
    @publication = N'MergePub_ComputerShop',
    @frequency_type = 1,
    @job_login = NULL,
    @job_password = NULL,
    @publisher_security_mode = 1;

GO

-- ============================================
-- ШАГ 3: ДОБАВЛЕНИЕ ФУНКЦИИ ПАРАМЕТРИЗАЦИИ ФИЛЬТРА
-- ============================================
-- Создаем функцию для параметризованного фильтра

CREATE FUNCTION [dbo].[fn_BranchFilter] (@BranchID INT)
RETURNS BIT
AS
BEGIN
    DECLARE @Result BIT;
    IF @BranchID IS NOT NULL
        SET @Result = 1;
    ELSE
        SET @Result = 0;
    RETURN @Result;
END;
GO

-- ============================================
-- ШАГ 4: ДОБАВЛЕНИЕ СТАТЕЙ С ПАРАМЕТРИЗОВАННЫМИ ФИЛЬТРАМИ
-- ============================================

-- 4.1. Branches
EXEC sp_addmergearticle
    @publication = N'MergePub_ComputerShop',
    @article = N'Branches',
    @source_owner = N'dbo',
    @source_object = N'Branches',
    @destination_owner = N'dbo',
    @type = N'table',
    @pre_creation_cmd = N'drop',
    @schema_option = 0x000000010C034FD1,
    @subset_filterclause = N'[BranchID] = HOST_NAME()',
    @partition_options = 3,
    @subscriber_upload_options = 2,
    @identityrangemanagementoption = N'manual';

-- 4.2. Components
EXEC sp_addmergearticle
    @publication = N'MergePub_ComputerShop',
    @article = N'Components',
    @source_owner = N'dbo',
    @source_object = N'Components',
    @destination_owner = N'dbo',
    @type = N'table',
    @pre_creation_cmd = N'drop',
    @schema_option = 0x000000010C034FD1,
    @subset_filterclause = N'[BranchID] = HOST_NAME()',
    @partition_options = 1,
    @subscriber_upload_options = 2,
    @identityrangemanagementoption = N'manual';

-- 4.3. Orders
EXEC sp_addmergearticle
    @publication = N'MergePub_ComputerShop',
    @article = N'Orders',
    @source_owner = N'dbo',
    @source_object = N'Orders',
    @destination_owner = N'dbo',
    @type = N'table',
    @pre_creation_cmd = N'drop',
    @schema_option = 0x000000010C034FD1,
    @subset_filterclause = N'[BranchID] = HOST_NAME()',
    @partition_options = 1,
    @subscriber_upload_options = 0,
    @identityrangemanagementoption = N'manual';

-- 4.4. Employees
EXEC sp_addmergearticle
    @publication = N'MergePub_ComputerShop',
    @article = N'Employees',
    @source_owner = N'dbo',
    @source_object = N'Employees',
    @destination_owner = N'dbo',
    @type = N'table',
    @pre_creation_cmd = N'drop',
    @schema_option = 0x000000010C034FD1,
    @subset_filterclause = N'[BranchID] = HOST_NAME()',
    @partition_options = 1,
    @subscriber_upload_options = 2,
    @identityrangemanagementoption = N'manual';

-- 4.5. Brands (без фильтра)
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

-- 4.6. Categories (без фильтра)
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

GO

-- Добавляем фильтры соединения (аналогично оригинальному скрипту)
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

GO

-- Создаем подписки (аналогично оригинальному скрипту)
EXEC sp_addmergesubscription
    @publication = N'MergePub_ComputerShop',
    @subscriber = @@SERVERNAME,
    @subscriber_db = N'Branch1_Merge_Comp',
    @subscription_type = N'push',
    @sync_type = N'automatic',
    @subscriber_type = N'global';

EXEC sp_addmergesubscription
    @publication = N'MergePub_ComputerShop',
    @subscriber = @@SERVERNAME,
    @subscriber_db = N'Branch2_Merge_Comp',
    @subscription_type = N'push',
    @sync_type = N'automatic',
    @subscriber_type = N'global';

GO

-- Добавляем агентов слияния
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

GO

-- Запускаем создание снимка
EXEC sp_startpublication_snapshot
    @publication = N'MergePub_ComputerShop';

PRINT 'Моментальный снимок создается... Ждите 3-5 минут';
WAITFOR DELAY '00:05:00';

GO
*/




