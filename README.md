<img align="right" src="static/assets/image/logo-64.png"/>

# REVS

## Introduction

REVS(Relatedness Extraction & Visualization System) is a web-based system to extract and visualize the relatedness of a pair of queried entities in a knowledge graph.

## Live Demonstration

We provide a live demonstration website [here](https://kg.cse.unsw.edu.au/apps/revs/). 

**However**, due to a potential heavy load on the query processing and some security risks, we do not guarantee that this website is available all the time. When it is unavailable, you may read the following sections and install REVS in your own system. 

## Installation

### Check Prerequisites

- Python 3 & Virtualenv

  We will use `virtualenv` to create a virtual python 3 environment. Make sure you have installed it in your system. 

- Postgres 9.4+
  
  Create a new relational database for storing and querying the knowledge graph. 
   
- Mongodb 3.4+

  Create a new NoSQL database for caching queries.

- ElasticSearch 5.4+

  This enables the entity name auto-completion. You do not need to do any initializations right now.  

### Edit Configurations

Edit the `config.json` file to change the following settings according to your system environment.

1. Postgres connection string

      ```json
      "postgres": {
          "connection_string": "host='YOUR_POSTGRES_HOST' port='YOUR_POSTGRES_PORT' dbname='DB_NAME' user='DB_USER' password='DB_PASS'"
      },
      ```
  
2. MongoDB connection URL and database name
    
      ```json
      "mongo": {
          "url": "mongodb://USER_NAME:PASSWORD@YOUR_MONGO_HOST:YOUR_MONGO_PORT/?authSource=USER_AUTH_SOURCE_DB",
          "db": "DB_NAME"
      },
      ```
      
      `USER_NAME:PASSWORD@` and `/?authSource=USER_AUTH_SOURCE_DB` are required only if you have enabled the authentication of your MongoDB. You do not have to change the other settings in the `mongo` block.
  
3. ElasticSearch connection URL

      ```json
      "elastic_search": {
          "url": "YOUR_ELASTIC_HOST:YOUR_ELASTIC_PORT"
      },
      ```

### Import Datasets

1. Download DBpedia (e.g. [DBpedia-2016-04](http://wiki.dbpedia.org/downloads-2016-04)) or any other knowledge graphs with `NT/TTL` format. We only need the following 3 types of data files.
 
   1. Ontology (e.g. [DBpedia Ontology (nt)](http://downloads.dbpedia.org/2016-04/dbpedia_2016-04.nt)). Rename the file into `ontology.ttl`.
   2. Facts (e.g. [DBpedia Mapping-based Objects (ttl)](http://downloads.dbpedia.org/2016-04/core-i18n/en/mappingbased_objects_en.ttl.bz2), **decompess** it first). Rename the file into `facts.ttl`.
   3. Instance Types (e.g. [DBpedia Instance Types (ttl)](http://downloads.dbpedia.org/2016-04/core-i18n/en/instance_types_en.ttl.bz2), **decompess** it first). Rename the file into `instance_types.ttl`.
   
   Assume you put these files in a folder named `DATA_FOLDER`.
   
2. Convert `TTL` files into `TSV` files. We have provided a simple script to do this.

   ```bash
   cd DATA_FOLDER
   python SOURCE_FOLDER/scripts/ttl2tsv.py ontology.ttl facts.ttl instance_types.ttl
   ```
   
   Here, `SOURCE_FOLDER` is the root directory of this project repository.
   
3. Remove the redundant predicate column in `instance_types.tsv` because all the predicates should be the same and we do not want to store them in the database.

   ```bash
   cd DATA_FOLDER
   cut -f1,3 instance_types.tsv > tmp.tsv && mv tmp.tsv instance_types.tsv
   ```

4. Import data into Postgres.

   ```bash
   cd DATA_FOLDER
   psql -h YOUR_POSTGRES_HOST -p YOUR_POSTGRES_PORT -U DB_USER -d DB_NAME -a -f SOURCE_FOLDER/scripts/import_db.sql
   ```
   
   Use your real parameters for accessing the Postgres.

### Setup Environment

1. Create Python virtual enviroment

    ```bash
    virtualenv -p python3 VENV_HOME
    source VENV_HOME/bin/activate
    ```
    
    You may put this `VENV_HOME` at any place you like.
    
2. Upgrade `pip` to the latest version
    
    ```bash
    pip install -U pip
    ```

3. Install Python dependency packages

    ```bash
    cd SOURCE_FOLDER
    pip install -r requirements.txt
    ```
    
### Initialize Other Components

1. Build entity index in ElasticSearch

   ```bash
   source VENV_HOME/bin/activate # if you have not activated the virtual environment
   cd SOURCE_FOLDER
   export PYTHONPATH="$PWD"
   python ./scripts/index_entities.py
   ```
    
### Start REVS server

   ```bash
   source VENV_HOME/bin/activate # if you have not activated the virtual environment
   cd SOURCE_FOLDER
   python server.py
   ```
   
   Then, open [http://localhost:8055](http://localhost:8055) in your browser to access it.
   
## Resources

  Please check the [wiki](https://github.com/DBWangGroupUNSW/revs/wiki) for any other resources, e.g. the **questions** we used in our user-based evaluation.
  
## Citation

Please cite our paper as below if you are using the code or the resources in this repository.

> Miao, Y., Qin, J. & Wang, W., 2017. Graph Summarization for Entity Relatedness Visualization. In Proceedings of the 40th International ACM SIGIR Conference on Research and Development in Information Retrieval. SIGIR ’17. New York, NY, USA: ACM, pp. 1161–1164.

## LICENSE
    
    The MIT License (MIT)
    
    Copyright (c) 2017 Yukai Miao
    
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
