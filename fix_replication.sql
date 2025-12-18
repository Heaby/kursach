-- ============================================
-- СКРИПТ ДЛЯ ИСПРАВЛЕНИЯ ПРОБЛЕМ РЕПЛИКАЦИИ
-- ============================================

USE [Main_Merge_Comp];
GO

PRINT '=== ИСПРАВЛЕНИЕ ПРОБЛЕМ РЕПЛИКАЦИИ ===';
PRINT '';

-- 1. Проверяем, готов ли моментальный снимок
PRINT '1. Проверка готовности моментального снимка...';
DECLARE @snapshot_ready BIT;
SELECT @snapshot_ready = snapshot_ready 
FROM sysmergepublications 
WHERE name = 'MergePub_ComputerShop';

IF @snapshot_ready = 0
BEGIN
    PRINT 'Моментальный снимок не готов. Запускаем создание...';
    
    -- Запускаем создание моментального снимка
    EXEC sp_startpublication_snapshot
        @publication = N'MergePub_ComputerShop';
    
    PRINT 'Ожидание создания моментального снимка (это может занять несколько минут)...';
    WAITFOR DELAY '00:05:00';
    
    -- Проверяем снова
    SELECT @snapshot_ready = snapshot_ready 
    FROM sysmergepublications 
    WHERE name = 'MergePub_ComputerShop';
    
    IF @snapshot_ready = 0
    BEGIN
        PRINT 'ПРЕДУПРЕЖДЕНИЕ: Моментальный снимок все еще не готов.';
        PRINT 'Проверьте журнал агента моментальных снимков в SQL Server Agent.';
    END
    ELSE
    BEGIN
        PRINT 'Моментальный снимок готов!';
    END
END
ELSE
BEGIN
    PRINT 'Моментальный снимок готов.';
END
GO

-- 2. Проверяем статус подписок и агентов
PRINT '';
PRINT '2. Проверка статуса подписок...';
USE [Main_Merge_Comp];
GO

SELECT 
    subscriber_server AS [Подписчик],
    subscriber_db AS [База подписчика],
    subscription_type AS [Тип подписки],
    status AS [Статус],
    CASE status
        WHEN 0 THEN 'Неактивна'
        WHEN 1 THEN 'Активна'
        WHEN 2 THEN 'Ошибка'
    END AS [Описание статуса]
FROM sysmergesubscriptions
WHERE publisher = DB_NAME()
  AND publisher_db = DB_NAME()
  AND publication = 'MergePub_ComputerShop';
GO

-- 3. Запускаем синхронизацию через SQL Server Agent Jobs
PRINT '';
PRINT '3. Запуск агентов слияния через SQL Server Agent...';

USE [msdb];
GO

-- Получаем имена заданий для агентов слияния
DECLARE @job1_name NVARCHAR(128);
DECLARE @job2_name NVARCHAR(128);

SELECT @job1_name = name 
FROM msdb.dbo.sysjobs 
WHERE name LIKE '%MergePub_ComputerShop%Branch1_Merge_Comp%';

SELECT @job2_name = name 
FROM msdb.dbo.sysjobs 
WHERE name LIKE '%MergePub_ComputerShop%Branch2_Merge_Comp%';

IF @job1_name IS NOT NULL
BEGIN
    PRINT 'Запускаем задание: ' + @job1_name;
    EXEC msdb.dbo.sp_start_job @job_name = @job1_name;
    WAITFOR DELAY '00:02:00';
END
ELSE
BEGIN
    PRINT 'ПРЕДУПРЕЖДЕНИЕ: Задание для Branch1_Merge_Comp не найдено';
END

IF @job2_name IS NOT NULL
BEGIN
    PRINT 'Запускаем задание: ' + @job2_name;
    EXEC msdb.dbo.sp_start_job @job_name = @job2_name;
    WAITFOR DELAY '00:02:00';
END
ELSE
BEGIN
    PRINT 'ПРЕДУПРЕЖДЕНИЕ: Задание для Branch2_Merge_Comp не найдено';
END

-- Альтернативный способ: получаем все задания агентов слияния
PRINT '';
PRINT '4. Все задания агентов слияния для этой публикации:';
SELECT 
    name AS [Имя задания],
    enabled AS [Включено],
    date_modified AS [Дата изменения]
FROM msdb.dbo.sysjobs
WHERE name LIKE '%MergePub_ComputerShop%'
ORDER BY name;
GO

-- 5. Если синхронизация не сработала, попробуем пересоздать снимок
PRINT '';
PRINT '5. Если проблема сохраняется, попробуйте:';
PRINT '   - Проверить SQL Server Agent (должен быть запущен)';
PRINT '   - Проверить журналы агентов в SQL Server Management Studio';
PRINT '   - Убедиться, что логины merge_agent_1 и merge_agent_2 существуют';
PRINT '   - Проверить права доступа к папке моментальных снимков';
GO

-- 6. Проверяем, появились ли таблицы
PRINT '';
PRINT '6. Проверка наличия таблиц после синхронизации...';

USE [Branch1_Merge_Comp];
GO

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Branches')
BEGIN
    PRINT 'Таблица Branches найдена в Branch1_Merge_Comp';
    SELECT COUNT(*) AS [Количество записей] FROM Branches;
END
ELSE
BEGIN
    PRINT 'Таблица Branches НЕ найдена в Branch1_Merge_Comp';
END

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Components')
BEGIN
    PRINT 'Таблица Components найдена в Branch1_Merge_Comp';
    SELECT COUNT(*) AS [Количество записей] FROM Components;
END
ELSE
BEGIN
    PRINT 'Таблица Components НЕ найдена в Branch1_Merge_Comp';
END
GO

USE [Branch2_Merge_Comp];
GO

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Branches')
BEGIN
    PRINT 'Таблица Branches найдена в Branch2_Merge_Comp';
    SELECT COUNT(*) AS [Количество записей] FROM Branches;
END
ELSE
BEGIN
    PRINT 'Таблица Branches НЕ найдена в Branch2_Merge_Comp';
END

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Components')
BEGIN
    PRINT 'Таблица Components найдена в Branch2_Merge_Comp';
    SELECT COUNT(*) AS [Количество записей] FROM Components;
END
ELSE
BEGIN
    PRINT 'Таблица Components НЕ найдена в Branch2_Merge_Comp';
END
GO

PRINT '';
PRINT '=== ИСПРАВЛЕНИЕ ЗАВЕРШЕНО ===';
GO

