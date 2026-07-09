-- File 1: DDL - creates the table (runs only when the table does NOT exist)
CREATE TABLE employees (
    emp_id     SERIAL PRIMARY KEY,
    emp_name   VARCHAR(100) NOT NULL,
    department VARCHAR(50),
    salary     NUMERIC(10,2),
    hired_at   TIMESTAMP DEFAULT now()
);
