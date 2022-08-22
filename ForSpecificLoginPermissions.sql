DECLARE @loginname NVARCHAR(100)= 'test'; --add name which login you get permission
DECLARE @str NVARCHAR(MAX), @dbname NVARCHAR(MAX), @dbname1 NVARCHAR(MAX), @script NVARCHAR(MAX), @login NVARCHAR(50);
IF OBJECT_ID('tempdb..#Results') IS NOT NULL
    DROP TABLE #Results;
CREATE TABLE #Results
(loginname NVARCHAR(100), 
 script    NVARCHAR(MAX), 
 per_type  NVARCHAR(100)
);
IF OBJECT_ID('tempdb..#Results1') IS NOT NULL
    DROP TABLE #Results1;
CREATE TABLE #Results1
(dbname    NVARCHAR(100), 
 loginname NVARCHAR(100), 
 script    NVARCHAR(MAX), 
 per_type  NVARCHAR(100)
);
DECLARE MyCursor CURSOR
FOR SELECT name
    FROM master.sys.databases
    WHERE name NOT IN('aspnetdb')
    AND is_read_only = 0
    AND state = 0;
OPEN MyCursor;
FETCH NEXT FROM MyCursor INTO @dbname;
WHILE @@FETCH_STATUS = 0
    BEGIN

        ----Object_levels_permission----
        SET @str = 'use [' + @dbname + '];' + '

SELECT USER_NAME(usr.principal_id) COLLATE database_default as login_name, CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
    + SPACE(1) + perm.permission_name + SPACE(1) + ''ON '' + QUOTENAME(USER_NAME(obj.schema_id)) + ''.'' + QUOTENAME(obj.name)
    + CASE WHEN cl.column_id IS NULL THEN SPACE(0) ELSE ''('' + QUOTENAME(cl.name) + '')'' END
    + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(USER_NAME(usr.principal_id)) COLLATE database_default
    + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END AS ''--Object Level Permissions''
    , ''Object_levels_permission'' as Per_Type
FROM  sys.database_permissions AS perm
    INNER JOIN
    sys.objects AS obj
    ON perm.major_id = obj.[object_id]
    INNER JOIN
    sys.database_principals AS usr
    ON perm.grantee_principal_id = usr.principal_id
    LEFT JOIN
    sys.columns AS cl
    ON cl.column_id = perm.minor_id AND cl.[object_id] = perm.major_id
ORDER BY perm.permission_name ASC, perm.state_desc ASC';
        INSERT INTO #Results
        EXEC sp_executesql 
             @str;
        ----Databases_levels_permission----
        SET @str = 'use [' + @dbname + '];' + '
SELECT USER_NAME(usr.principal_id) COLLATE database_default as login_name,  CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
    + SPACE(1) + perm.permission_name + SPACE(1)
    + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(USER_NAME(usr.principal_id)) COLLATE database_default
    + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END AS ''--Database Level Permissions''
    , ''Databases_levels_permission'' as Per_Type
FROM  sys.database_permissions AS perm
    INNER JOIN
    sys.database_principals AS usr
    ON perm.grantee_principal_id = usr.principal_id
WHERE  perm.major_id = 0
ORDER BY perm.permission_name ASC, perm.state_desc ASC';
        INSERT INTO #Results
        EXEC sp_executesql 
             @str;

        ----db_roles----
        SET @str = 'use [' + @dbname + '];' + 'SELECT DP2.name as login_name, ''EXEC sp_addrolemember [''+DP1.name+''],[''+DP2.name+'']''
, ''Database_roles'' as Per_Type
 FROM sys.database_role_members AS DRM
 RIGHT OUTER JOIN sys.database_principals AS DP1
   ON DRM.role_principal_id = DP1.principal_id
inner JOIN sys.database_principals AS DP2
   ON DRM.member_principal_id = DP2.principal_id
WHERE DP1.type = ''R''
ORDER BY DP1.name';
        INSERT INTO #Results
        EXEC sp_executesql 
             @str;
        IF @dbname = 'master'
            BEGIN

                ----server_level_permissions----
                SET @str = 'use [' + @dbname + '];' + 'SELECT


        granteeserverprincipal.name AS grantee_principal_name
        , CASE
            WHEN sys.server_permissions.state = N''W''
                THEN N''GRANT''
            ELSE sys.server_permissions.state_desc
            END + N'' '' + sys.server_permissions.permission_name COLLATE SQL_Latin1_General_CP1_CI_AS + N'' TO '' + QUOTENAME(granteeserverprincipal.name) AS permissionstatement
    ,  sys.server_permissions.class_desc as per_type
FROM sys.server_principals AS granteeserverprincipal
INNER JOIN sys.server_permissions
    ON sys.server_permissions.grantee_principal_id = granteeserverprincipal.principal_id
INNER JOIN sys.server_principals AS grantorserverprinicipal
    ON grantorserverprinicipal.principal_id = sys.server_permissions.grantor_principal_id
    where sys.server_permissions.permission_name not like ''%connect%''  AND granteeserverprincipal.name not like  ''##MS%##''

ORDER BY granteeserverprincipal.name
    , sys.server_permissions.permission_name';
                INSERT INTO #Results
                EXEC sp_executesql 
                     @str;

                ----server_roles----
                SET @str = 'use [' + @dbname + '];' + 'SELECT


      memberserverprincipal.name AS member_principal_name
    , N''ALTER SERVER ROLE '' + QUOTENAME(roles.name) + N'' ADD MEMBER '' + QUOTENAME(memberserverprincipal.name) AS AddRoleMembersStatement
    ,  roles.type_desc AS role_type_desc
FROM sys.server_principals AS roles
INNER JOIN sys.server_role_members
    ON sys.server_role_members.role_principal_id = roles.principal_id
INNER JOIN sys.server_principals AS memberserverprincipal
    ON memberserverprincipal.principal_id = sys.server_role_members.member_principal_id
WHERE roles.type = N''R''
ORDER BY
     member_principal_name';
                INSERT INTO #Results
                EXEC sp_executesql 
                     @str;
            END;
        INSERT INTO #Results1
               SELECT @dbname, 
                      loginname, 
                      'use ' + @dbname + '; ' + script AS script, 
                      per_type
               FROM #Results;
        DELETE FROM #Results;
        FETCH NEXT FROM MyCursor INTO @dbname;
    END;
CLOSE MyCursor;
DEALLOCATE MyCursor;
SELECT *
FROM #Results1
WHERE loginname = @loginname
ORDER BY dbname,
         CASE
             WHEN PATINDEX('%Connect%', script) > 0
             THEN 1
             ELSE 2
         END;
