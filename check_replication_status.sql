-- ============================================
-- ДИАГНОСТИЧЕСКИЙ СКРИПТ ДЛЯ ПРОВЕРКИ РЕПЛИКАЦИИ
-- ============================================

USE [master];
GO

PRINT '=== ПРОВЕРКА СТАТУСА РЕПЛИКАЦИИ ===';
PRINT '';

-- 1. Проверяем существование баз данных
PRINT '1. Проверка существования баз данных:';
SELECT 
    name AS [Имя базы],
    database_id AS [ID],
    state_desc AS [Состояние]
FROM sys.databases 
WHERE name IN ('Main_Merge_Comp', 'Branch1_Merge_Comp', 'Branch2_Merge_Comp')
ORDER BY name;
GO

-- 2. Проверяем статус публикации
PRINT '';
PRINT '2. Проверка статуса публикации:';
USE [Main_Merge_Comp];
GO

SELECT 
    name AS [Публикация],
    status AS [Статус],
    CASE status
        WHEN 0 THEN 'Неактивна'
        WHEN 1 THEN 'Активна'
        WHEN 2 THEN 'Неактивна'
    END AS [Описание статуса]
FROM sysmergepublications
WHERE name = 'MergePub_ComputerShop';
GO

-- 3. Проверяем статус подписок
PRINT '';
PRINT '3. Проверка статуса подписок:';
SELECT 
    subscription_id AS [ID подписки],
    subscriber AS [Подписчик],
    subscriber_db AS [База подписчика],
    subscription_type AS [Тип],
    status AS [Статус],
    CASE status
        WHEN 0 THEN 'Неактивна'
        WHEN 1 THEN 'Активна'
        WHEN 2 THEN 'Ошибка'
    END AS [Описание статуса]
FROM sysmergesubscriptions
WHERE publication = 'MergePub_ComputerShop';
GO

-- 4. Проверяем статус моментальных снимков
PRINT '';
PRINT '4. Проверка статуса моментальных снимков:';
SELECT 
    name AS [Публикация],
    snapshot_jobid AS [ID задания снимка],
    snapshot_ready AS [Снимок готов]
FROM sysmergepublications
WHERE name = 'MergePub_ComputerShop';
GO

-- 5. Проверяем журнал агента моментальных снимков
PRINT '';
PRINT '5. Последние записи из журнала агента моментальных снимков:';
SELECT TOP 10
    time AS [Время],
    message AS [Сообщение]
FROM msdb.dbo.sysmergehistory
WHERE publication = 'MergePub_ComputerShop'
  AND agent_type = 1  -- Snapshot Agent
ORDER BY time DESC;
GO

-- 6. Проверяем, какие таблицы есть в базах филиалов
PRINT '';
PRINT '6. Проверка таблиц в Branch1_Merge_Comp:';
USE [Branch1_Merge_Comp];
GO

SELECT 
    TABLE_SCHEMA AS [Схема],
    TABLE_NAME AS [Имя таблицы],
    TABLE_TYPE AS [Тип]
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_TYPE = 'BASE TABLE'
  AND TABLE_NAME NOT LIKE 'sys%'
  AND TABLE_NAME NOT LIKE 'MSmerge%'
ORDER BY TABLE_NAME;
GO

PRINT '';
PRINT '7. Проверка таблиц в Branch2_Merge_Comp:';
USE [Branch2_Merge_Comp];
GO

SELECT 
    TABLE_SCHEMA AS [Схема],
    TABLE_NAME AS [Имя таблицы],
    TABLE_TYPE AS [Тип]
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_TYPE = 'BASE TABLE'
  AND TABLE_NAME NOT LIKE 'sys%'
  AND TABLE_NAME NOT LIKE 'MSmerge%'
ORDER BY TABLE_NAME;
GO

-- 8. Проверяем журнал агентов слияния
PRINT '';
PRINT '8. Последние записи из журнала агентов слияния:';
USE [master];
GO

SELECT TOP 20
    time AS [Время],
    subscriber AS [Подписчик],
    subscriber_db AS [База подписчика],
    message AS [Сообщение]
FROM msdb.dbo.sysmergehistory
WHERE publication = 'MergePub_ComputerShop'
  AND agent_type = 2  -- Merge Agent
ORDER BY time DESC;
GO

PRINT '';
PRINT '=== ДИАГНОСТИКА ЗАВЕРШЕНА ===';
PRINT '';
PRINT 'Если таблицы отсутствуют в базах филиалов, выполните скрипт fix_replication.sql';
GO




