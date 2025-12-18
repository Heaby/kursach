-- ============================================
-- РУЧНАЯ СИНХРОНИЗАЦИЯ ЧЕРЕЗ SQL SERVER AGENT
-- ============================================
-- 
-- Этот скрипт показывает, как запустить синхронизацию вручную
-- через задания SQL Server Agent
-- ============================================

USE [msdb];
GO

PRINT '=== РУЧНАЯ СИНХРОНИЗАЦИЯ РЕПЛИКАЦИИ ===';
PRINT '';

-- 1. Находим все задания агентов слияния для нашей публикации
PRINT '1. Поиск заданий агентов слияния...';
SELECT 
    job_id AS [ID задания],
    name AS [Имя задания],
    enabled AS [Включено],
    CASE enabled
        WHEN 0 THEN 'Выключено'
        WHEN 1 THEN 'Включено'
    END AS [Статус]
FROM dbo.sysjobs
WHERE name LIKE '%MergePub_ComputerShop%'
ORDER BY name;
GO

-- 2. Запускаем задания вручную
PRINT '';
PRINT '2. Запуск заданий агентов слияния...';
PRINT '   (Раскомментируйте нужные строки)';

-- Для Branch1_Merge_Comp
/*
DECLARE @job_name1 NVARCHAR(128);
SELECT @job_name1 = name 
FROM dbo.sysjobs 
WHERE name LIKE '%MergePub_ComputerShop%Branch1_Merge_Comp%';

IF @job_name1 IS NOT NULL
BEGIN
    PRINT 'Запускаем: ' + @job_name1;
    EXEC dbo.sp_start_job @job_name = @job_name1;
END
*/

-- Для Branch2_Merge_Comp
/*
DECLARE @job_name2 NVARCHAR(128);
SELECT @job_name2 = name 
FROM dbo.sysjobs 
WHERE name LIKE '%MergePub_ComputerShop%Branch2_Merge_Comp%';

IF @job_name2 IS NOT NULL
BEGIN
    PRINT 'Запускаем: ' + @job_name2;
    EXEC dbo.sp_start_job @job_name = @job_name2;
END
*/

PRINT '';
PRINT '3. Проверка истории выполнения заданий...';
SELECT TOP 20
    j.name AS [Имя задания],
    h.step_name AS [Шаг],
    h.run_date AS [Дата],
    h.run_time AS [Время],
    h.run_duration AS [Длительность (сек)],
    CASE h.run_status
        WHEN 0 THEN 'Ошибка'
        WHEN 1 THEN 'Успешно'
        WHEN 2 THEN 'Повтор'
        WHEN 3 THEN 'Отменено'
        WHEN 4 THEN 'В процессе'
    END AS [Статус],
    h.message AS [Сообщение]
FROM dbo.sysjobhistory h
INNER JOIN dbo.sysjobs j ON h.job_id = j.job_id
WHERE j.name LIKE '%MergePub_ComputerShop%'
ORDER BY h.run_date DESC, h.run_time DESC;
GO

PRINT '';
PRINT '=== ИНСТРУКЦИЯ ===';
PRINT 'Для запуска синхронизации:';
PRINT '1. Откройте SQL Server Management Studio';
PRINT '2. Перейдите в SQL Server Agent -> Jobs';
PRINT '3. Найдите задания вида: [Publisher]-[Publication]-[Subscriber]-[Database]-[GUID]';
PRINT '4. Щелкните правой кнопкой на задании -> Start Job at Step';
PRINT '';
PRINT 'ИЛИ используйте команду:';
PRINT 'EXEC msdb.dbo.sp_start_job @job_name = ''имя_задания'';';
GO




