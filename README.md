This repo contains RTL code for the R10K inspired N-way out-of-order processor as part of EECS 470 Computer Architecture Class. This project was done in collaboration with Rohan Varma, Jonathan Moore, Tarun Maddali, Guanxiao Yu and Harrison Centner.
The top level diagram of our R10k inspired OoO processor is shown below:

![top_level_eecs470](https://github.com/user-attachments/assets/100c11ce-2b68-4229-a800-4d085ffa1005)

The dispatch stage looks as follows: 

![dispatch](https://github.com/user-attachments/assets/ecbb7921-8569-40f2-afa5-b2c2493753a1)


Our out-of-order processor features (1): a fully N-way pipeline, (2) N arithmetic logic functional units, (3) an arbitrary amount of Load and 4-stage pipelined multiplier functional units, 
(4) a 2-bit saturating, correlated branch predictor, (5) early branch resolution, (6) forwarding and speculation of loads, (7) a non-blocking instruction cache, and (8) a write-back data cache
