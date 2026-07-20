resource Handle { ptr byte data; }

void bad(ref Handle destination, Handle replacement) {
    destination = replacement;
}
