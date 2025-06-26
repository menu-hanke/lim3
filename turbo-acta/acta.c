#include <math.h>
#include "acta.h"

#ifndef ACTA_MODELS
#define ACTA_MODELS 1
#endif

#ifndef ACTA_UPDATE
#define ACTA_UPDATE 1
#endif

#if ACTA_MODELS

double acta_xg(double *f, double *x, double *d, int n)
{
	double XG = 0, G = 0;
	for (int i=0; i<n; i++) {
		double fd2 = f[i]*d[i]*d[i];
		XG += x[i]*fd2;
		G += fd2;
	}
	return G == 0 ? 0 : XG/G;
}

double acta_G(double *f, double *d, int n)
{
	double D2 = 0;
	for (int i=0; i<n; i++)
		D2 += f[i]*d[i]*d[i];
	return 0.25 * 1e-4 * M_PI * D2;
}

double acta_hdom(double *fs, double *ds, double *hs, int n)
{
	// as long as we do less than around log(n) iterations, this is faster than sorting.
	// in fact, log(n) grows with n, but our iteration count doesn't, so with large enough n
	// this is better. i assume (but haven't tested) that it's also better for small n because
	// the branch misses from sorting will dominate the runtime with small n.
	// a quickselect variant might be faster for very large n, but i don't feel like implementing
	// it to test (chatgpt gave me garbage code).
	// this could very easily be vectorized to do 8 elements at a time (or 16 floats) with avx512,
	// but i don't have the time for that, or an avx512 cpu.
	double dmax = INFINITY;
	double r = 100, dw = 0, w = 0;
	for (;;) {
		double dmax1 = 0;
		for (int i=0; i<n; i++) {
			double d = ds[i];
			dmax1 = d > dmax1 ? (d < dmax ? d : dmax1) : dmax1;
			if (d == dmax) {
				double f = fs[i];
				double h = hs[i];
				if (f >= r) {
					return (dw+r*h)*0.01;
				} else {
					dw += f*h;
					w += f;
					r -= f;
				}
			}
		}
		dmax = dmax1;
		if (dmax == 0) break;
	}
	if (w == 0) return 0;
	return dw/w;
}

double acta_id5p1_pine(double d, double h, double ag, double dg, double G, double hdom)
{
	return 0.01 * exp(
		5.4625
		- 0.6675 * log(ag)
		- 0.4758 * log(G)
		+ 0.1173 * log(dg)
		- 0.9442 * log(hdom)
		- 0.3631 * log(d)
		+ 0.7762 * log(h)
	);
}

double acta_id5p1_spruce(double d, double h, double ag, double dg, double hg, double G)
{
	return 0.01 * exp(
		6.9342
		- 0.8808 * log(ag)
		- 0.4982 * log(G)
		+ 0.4159 * log(dg)
		- 0.3865 * log(hg)
		- 0.6267 * log(d)
		+ 0.1287 * log(h)
	);
}

double acta_ih5p1_pine(double h, double ag, double dg)
{
	return 0.01 * exp(
		5.4636
		- 0.9002 * log(ag)
		+ 0.5475 * log(dg)
		- 1.1339 * log(h)
	);
}

double acta_ih5p1_spruce(double d, double h, double ag, double dg, double hg, double G)
{
	return 0.01 * /* NO exp */ (
		12.7402
		- 1.1786 * log(ag)
		- 0.0937 * log(G)
		- 0.1434 * log(dg)
		- 0.8070 * log(hg)
		+ 0.7563 * log(d)
		- 2.0522 * log(h)
	);
}

#endif

#if ACTA_UPDATE

void acta_update(double *f, double *d, double *h, double *a, char *s, int n)
{
	// optimizations you could do, from (roughly) most to least impactful:
	// * do the log transform here: log_ag = log(acta_xg(f,a,d,n)) etc.
	// * collect pine indices and spruce indices into work arrays (can be done branchlessly),
	//   and iterate over each array. this eliminates the unpredictable `s[i] == 1` check.
	// * lazily compute hdom when you see the first pine
	// * do the log transform for d and h only once
	double ag = acta_xg(f, a, d, n);
	double dg = acta_xg(f, d, d, n);
	double hg = acta_xg(f, h, d, n);
	double hdom = acta_hdom(f, d, h, n);
	double G = acta_G(f, d, n);
	for (int i=0; i<n; i++) {
		double di = d[i];
		double hi = h[i];
		double id, ih;
		if (s[i] == 1) {
			id = acta_id5p1_pine(di, hi, ag, dg, G, hdom);
			ih = acta_ih5p1_pine(hi, ag, dg);
		} else {
			id = acta_id5p1_spruce(di, hi, ag, dg, hg, G);
			ih = acta_ih5p1_spruce(di, hi, ag, dg, hg, G);
		}
		// 1 year growth ratio -> 5 years growth ratio
		id += 1;
		ih += 1;
		id = (id*id)*(id*id)*id;
		ih = (ih*ih)*(ih*ih)*ih;
		d[i] = di * id;
		h[i] = hi * ih;
		a[i] += 5;
	}
}

#endif
