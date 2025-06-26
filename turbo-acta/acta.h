#pragma once

double acta_xg(double *f, double *x, double *d, int n);
double acta_G(double *f, double *d, int n);
double acta_hdom(double *fs, double *ds, double *hs, int n);
double acta_id5p1_pine(double d, double h, double ag, double dg, double G, double hdom);
double acta_id5p1_spruce(double d, double h, double ag, double dg, double hg, double G);
double acta_ih5p1_pine(double h, double ag, double dg);
double acta_ih5p1_spruce(double d, double h, double ag, double dg, double hg, double G);
void acta_update(double *f, double *d, double *h, double *a, char *s, int n);
