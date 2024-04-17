#include <cognit/ip_utils.h>

static int
    inet_pton4(src, dst)
        const char* src;
u_char* dst;
{
    static const char digits[] = "0123456789";
    int saw_digit, octets, ch;
    u_char tmp[INADDRSZ], *tp;

    saw_digit   = 0;
    octets      = 0;
    *(tp = tmp) = 0;
    while ((ch = *src++) != '\0')
    {
        const char* pch;

        if ((pch = strchr(digits, ch)) != NULL)
        {
            u_int new = *tp * 10 + (pch - digits);

            if (new > 255)
                return (0);
            *tp = new;
            if (!saw_digit)
            {
                if (++octets > 4)
                    return (0);
                saw_digit = 1;
            }
        }
        else if (ch == '.' && saw_digit)
        {
            if (octets == 4)
                return (0);
            *++tp     = 0;
            saw_digit = 0;
        }
        else
            return (0);
    }
    if (octets < 4)
        return (0);
    /* bcopy(tmp, dst, INADDRSZ); */
    memcpy(dst, tmp, INADDRSZ);
    return (1);
}

/* int
 * inet_pton6(src, dst)
 *	convert presentation level address to network order binary form.
 * return:
 *	1 if `src' is a valid [RFC1884 2.2] address, else 0.
 * notice:
 *	(1) does not touch `dst' unless it's returning 1.
 *	(2) :: in a full address is silently ignored.
 * credit:
 *	inspired by Mark Andrews.
 * author:
 *	Paul Vixie, 1996.
 */
static int
    inet_pton6(src, dst)
        const char* src;
u_char* dst;
{
    static const char xdigits_l[] = "0123456789abcdef",
                      xdigits_u[] = "0123456789ABCDEF";
    u_char tmp[IN6ADDRSZ], *tp, *endp, *colonp;
    const char *xdigits, *curtok;
    int ch, saw_xdigit;
    u_int val;

    memset((tp = tmp), 0, IN6ADDRSZ);
    endp   = tp + IN6ADDRSZ;
    colonp = NULL;
    /* Leading :: requires some special handling. */
    if (*src == ':')
        if (*++src != ':')
            return (0);
    curtok     = src;
    saw_xdigit = 0;
    val        = 0;
    while ((ch = *src++) != '\0')
    {
        const char* pch;

        if ((pch = strchr((xdigits = xdigits_l), ch)) == NULL)
            pch = strchr((xdigits = xdigits_u), ch);
        if (pch != NULL)
        {
            val <<= 4;
            val |= (pch - xdigits);
            if (val > 0xffff)
                return (0);
            saw_xdigit = 1;
            continue;
        }
        if (ch == ':')
        {
            curtok = src;
            if (!saw_xdigit)
            {
                if (colonp)
                    return (0);
                colonp = tp;
                continue;
            }
            if (tp + INT16SZ > endp)
                return (0);
            *tp++      = (u_char)(val >> 8) & 0xff;
            *tp++      = (u_char)val & 0xff;
            saw_xdigit = 0;
            val        = 0;
            continue;
        }
        if (ch == '.' && ((tp + INADDRSZ) <= endp) && inet_pton4(curtok, tp) > 0)
        {
            tp += INADDRSZ;
            saw_xdigit = 0;
            break; /* '\0' was seen by inet_pton4(). */
        }
        return (0);
    }
    if (saw_xdigit)
    {
        if (tp + INT16SZ > endp)
            return (0);
        *tp++ = (u_char)(val >> 8) & 0xff;
        *tp++ = (u_char)val & 0xff;
    }
    if (colonp != NULL)
    {
        /*
		 * Since some memmove()'s erroneously fail to handle
		 * overlapping regions, we'll do the shift by hand.
		 */
        const int n = tp - colonp;
        int i;

        for (i = 1; i <= n; i++)
        {
            endp[-i]      = colonp[n - i];
            colonp[n - i] = 0;
        }
        tp = endp;
    }
    if (tp != endp)
        return (0);
    /* bcopy(tmp, dst, IN6ADDRSZ); */
    memcpy(dst, tmp, IN6ADDRSZ);
    return (1);
}

int is_ipv4(const char* ip)
{
    unsigned char buf[4];
    return inet_pton4(ip, buf);
}

int is_ipv6(const char* ip)
{
    unsigned char buf[16];
    return inet_pton6(ip, buf);
}

int get_ip_version(const char* ip)
{
    if (is_ipv4(ip) == 1)
        return IP_V4;
    if (is_ipv6(ip) == 1)
        return IP_V6;
    return 0; // No es ni IPv4 ni IPv6
}