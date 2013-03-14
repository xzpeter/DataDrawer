# Background

There are many datasets in the world that are formed in such a format below:

```
var1	var2     ...	varM	res1	res2 	...	resN
----------------------------------------------------------
v(1,1)	v(1,2)	 ...	v(1,M)	r(1,1)	r(1,2)	...	r(1,N)
v(2,1)	v(2,2)	 ...	v(2,M)	r(2,1)	r(2,2)	...	r(2,N)
...
v(K,1)	v(K,2)	 ... 	v(K,M)	r(K,1)	r(K,2) 	...	r(K,N)
```

Which is a **K*(M+N)** matrix. Each line means one "experiment result"
(possibly). This is more like a multi-input, multi-output blackbox, while
the variables settled down, we can know the results:

var1...M   |----------| res1...N
---------> | The BOX  | -------->
		   |----------|

Sometimes, we want to know how the variables influnce the
results. But... The data is too huge, and I don't want to sort it, select
data, draw graph each time to see the curves. So...

I decided to write this tool to draw all the curves for me. 

Input of this drawer should be *.csv file currently. 

# Required software

Currently this tool only works under Linux. 

## Required binaries
- gnuplot
- convert
- eog

## Required Perl modules
- Chart::Gnuplot
- Term::Menus

# Usage

Please check --help.

# CSV file format

Please take `sas-15k-data.csv` as am example. It's format Should be something like:

```
var1,var2,var3,...,varM,,res1,res2,...,resN
var1,var2,var3,...,varM,,res1,res2,...,resN
var1,var2,var3,...,varM,,res1,res2,...,resN
```

Here to seperate variables from test results, I used two commas **,,** to
seperate (or to say, add an empty column beteween the two blocks if you
open it in an Excel application).

