<?php

declare(strict_types=1);

namespace VPNMinute\Core\Exception\Main;

/**
 * Exception to extend for user errors. These exceptions should be safely displayed and acknowledge by final users.
 */
abstract class UserException extends \Exception
{
}
