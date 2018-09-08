#ifndef video
#define video

void fill_screen (char *vidptr, char c, char a);
void put_string (char *vidptr, char *str, char a);
void scroll_screen (char *vidptr, unsigned int rows);
void set_cursor (unsigned int x, unsigned int y);

#endif