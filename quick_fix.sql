-- ============================================
-- БЫСТРОЕ ИСПРАВЛЕНИЕ ПРОБЛЕМЫ С ФИЛЬТРАЦИЕЙ
-- ============================================
-- 
-- Проблема: фильтр использует SUSER_SNAME() с substring(), что может не работать
-- Решение: проверим статус снимков и запустим синхронизацию вручную
-- ============================================

USE [Main_Merge_Comp];
GO

PRINT '=== БЫСТРОЕ ИСПРАВЛЕНИЕ ===';
PRINT '';

-- 1. Проверяем статус моментального снимка
PRINT '1. Проверка статуса моментального снимка...';
SELECT 
    name AS [Публикация],
    snapshot_ready AS [Снимок готов (0=нет, 1=да)]
FROM sysmergepublications
WHERE name = 'MergePub_ComputerShop';
GO

-- 2. Если снимок не готов, создаем его
DECLARE @snapshot_ready BIT;
SELECT @snapshot_ready = snapshot_ready 
FROM sysmergepublications 
WHERE name = 'MergePub_ComputerShop';

IF @snapshot_ready = 0
BEGIN
    PRINT '';
    PRINT '2. Моментальный снимок не готов. Запускаем создание...';
    EXEC sp_startpublication_snapshot @publication = N'MergePub_ComputerShop';
    PRINT '   Ожидайте 5-10 минут для создания снимка...';
    PRINT '   Проверьте статус в SQL Server Agent -> Jobs';
END
ELSE
BEGIN
    PRINT '';
    PRINT '2. Моментальный снимок готов.';
END
GO

-- 3. Проверяем статус подписок
PRINT '';
PRINT '3. Проверка статуса подписок...';
SELECT 
    subscriber_db AS [База подписчика],
    status AS [Статус],
    CASE status
        WHEN 0 THEN 'Неактивна'
        WHEN 1 THEN 'Активна'
        WHEN 2 THEN 'Ошибка'
    END AS [Описание]
FROM sysmergesubscriptions
WHERE publication = 'MergePub_ComputerShop';
GO

-- 4. ВАЖНО: Проверяем, какие таблицы есть в базе подписчика (через sys.tables)
PRINT '';
PRINT '4. Проверка таблиц в Branch1_Merge_Comp через sys.tables...';
EXEC('USE [Branch1_Merge_Comp]; SELECT name AS [Имя таблицы] FROM sys.tables WHERE name NOT LIKE ''sys%'' AND name NOT LIKE ''MSmerge%'' ORDER BY name');
GO

PRINT '';
PRINT '5. Проверка таблиц в Branch2_Merge_Comp через sys.tables...';
EXEC('USE [Branch2_Merge_Comp]; SELECT name AS [Имя таблицы] FROM sys.tables WHERE name NOT LIKE ''sys%'' AND name NOT LIKE ''MSmerge%'' ORDER BY name');
GO

-- 5. Если таблицы отсутствуют, проблема в фильтрации или снимках
PRINT '';
PRINT '=== ДИАГНОСТИКА ===';
PRINT '';
PRINT 'Если таблицы отсутствуют, возможные причины:';
PRINT '1. Моментальный снимок еще не создан (подождите 5-10 минут)';
PRINT '2. Фильтр SUSER_SNAME() работает некорректно';
PRINT '3. SQL Server Agent не запущен';
PRINT '';
PRINT 'РЕКОМЕНДАЦИИ:';
PRINT '1. Убедитесь, что SQL Server Agent запущен';
PRINT '2. Проверьте журнал агента моментальных снимков в SSMS';
PRINT '3. Если снимок готов, но таблицы отсутствуют - проблема в фильтрации';
PRINT '4. Используйте fix_replication.sql для принудительной синхронизации';
GO




