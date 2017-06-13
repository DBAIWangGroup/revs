-- Init
SET client_encoding TO 'utf-8';

-- Import ontology
DROP TABLE IF EXISTS ontology;
CREATE TABLE ontology (
  subject   text,
  predicate text,
  object    text
);

\copy ontology FROM 'ontology.tsv' NULL AS ''

-- Import facts
DROP TABLE IF EXISTS facts;
CREATE TABLE facts (
  subject   text,
  predicate text,
  object    text
);

\copy facts FROM 'facts.tsv' NULL AS ''

DELETE FROM facts
WHERE length(object) > 1000; -- We cannot build the index if the "object" is too long

-- Import instance types
DROP TABLE IF EXISTS instanceTypes;
CREATE TABLE instanceTypes (
  entity    text,
  "type"    text
);

\copy instanceTypes FROM 'instance_types.tsv' NULL AS ''

-- Build Indices
CREATE INDEX ontologyIndexSubject ON ontology (subject);
CREATE INDEX factsIndexSubject ON facts (subject);
CREATE INDEX factsIndexObject ON facts (object);
CREATE INDEX instanceTypesIndexEntity ON instanceTypes (entity);
