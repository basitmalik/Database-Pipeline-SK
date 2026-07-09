-- File 2: DML - INSERT / UPDATE only (runs only when the table exists)
-- DELETE and TRUNCATE are blocked by the pipeline guard.

INSERT INTO employees (emp_name, department, salary)
VALUES ('Ali Khan', 'Engineering', 150000),
       ('Sara Ahmed', 'Marketing', 95000);

UPDATE employees
SET salary = salary * 1.10
WHERE department = 'Engineering';
