-- ============================================
-- ИСПРАВЛЕНИЕ ПРОБЛЕМЫ С ФИЛЬТРОМ SUSER_SNAME()
-- ============================================
-- 
-- ПРОБЛЕМА: Фильтр использует substring(SUSER_SNAME(), 11, 1), что может не работать
-- РЕШЕНИЕ: Использовать HOST_NAME() или явное указание значения фильтра
-- 
-- ВАЖНО: Этот скрипт требует пересоздания публикации!
-- ============================================

USE [Main_Merge_Comp];
GO

PRINT '=== ДИАГНОСТИКА ПРОБЛЕМЫ С ФИЛЬТРОМ ===';
PRINT '';

-- 1. Проверяем текущие фильтры в статьях
PRINT '1. Текущие фильтры в статьях:';
SELECT 
    article AS [Статья],
    subset_filterclause AS [Условие фильтра]
FROM sysmergearticles
WHERE publication = 'MergePub_ComputerShop'
  AND subset_filterclause IS NOT NULL
  AND subset_filterclause <> '';
GO

-- 2. Тестируем функцию SUSER_SNAME()
PRINT '';
PRINT '2. Тест функции SUSER_SNAME():';
SELECT 
    SUSER_SNAME() AS [Текущий пользователь],
    LEN(SUSER_SNAME()) AS [Длина имени],
    SUBSTRING(SUSER_SNAME(), 11, 1) AS [Символ на позиции 11],
    CASE 
        WHEN ISNUMERIC(SUBSTRING(SUSER_SNAME(), 11, 1)) = 1 
        THEN CAST(SUBSTRING(SUSER_SNAME(), 11, 1) AS INT)
        ELSE NULL
    END AS [Извлеченное число];
GO

-- 3. Тестируем для merge_agent_1
PRINT '';
PRINT '3. Тест для merge_agent_1 (должно быть BranchID = 1):';
EXECUTE AS LOGIN = 'merge_agent_1';
SELECT 
    SUSER_SNAME() AS [Пользователь],
    SUBSTRING(SUSER_SNAME(), 11, 1) AS [Извлеченный символ];
REVERT;
GO

-- 4. Тестируем для merge_agent_2
PRINT '';
PRINT '4. Тест для merge_agent_2 (должно быть BranchID = 2):';
EXECUTE AS LOGIN = 'merge_agent_2';
SELECT 
    SUSER_SNAME() AS [Пользователь],
    SUBSTRING(SUSER_SNAME(), 11, 1) AS [Извлеченный символ];
REVERT;
GO

PRINT '';
PRINT '=== РЕЗУЛЬТАТ ===';
PRINT 'Если извлеченный символ НЕ равен 1 или 2, фильтр работает неправильно!';
PRINT '';
PRINT 'РЕШЕНИЕ 1: Использовать другой фильтр (HOST_NAME или параметризованный)';
PRINT 'РЕШЕНИЕ 2: Использовать явное указание значения в подписке';
PRINT '';
PRINT 'См. скрипт alternative_solution.sql для пересоздания с правильными фильтрами';
GO




